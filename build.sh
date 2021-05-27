#!/usr/bin/env bash

set -e
set -o pipefail

usage() {
  cat <<EOF
NAME:
  $name

SYNOPSIS:
  $0 [options] <Distro> <Choreonoid tag>

DESCRIPTION:
  Builds Docker image of Grasp Plugin for Choreonoid and runs a
container.

OPTIONS:
  -h, --help
    Show this message.

  -b, --build-only
    Build Docker image then exits.

  -r, --run-only
    Without building image, only run an existing container.

  -d, --dry-run
    Just print commands.

  -f, --dockerfile
    Specify Dockerfile.

  -c, --cnoid-repo
    Specify Choreonoid repository. (Default: ${CNOID_REPO})

  -g, --grasp-repo
    Specify Grasp Plugin repository. (NOT YET SUPPORTED)

  -G, --grasp-tag
    Specify Grasp Plugin version. (NOT YET SUPPORTED)

  -M, --not-mount
    Do not mount Grasp Plugin directory when running container.

  -i, --image-name
    Specify Docker image repository name. (Default: ${IMAGE_REPO})

  -t, --image-tag
    Specify Docker image tag.

  <Distro>
    Ubuntu distro codename. Choose among xenial, bionic and focal.

  <Choreonoid tag>
    Specify Choreonoid released version.

EXAMPLES:
  1. Build Choreonoid with Grasp Plugin on Ubuntu 20.04.
        \$ $0 focal v1.7.0

  2. Build Choreonoid ver. 1.5.0 on Ubuntu 16.04 and exits without
     running a container.
        \$ $0 --build-only xenial v1.5.0

  3. Run a container already built.
        \$ $0 --run-only xenial v1.6.0
EOF
}

# Option flags.
BUILD_IMAGE=true
RUN_CONTAINER=true
DRY_RUN=false
DOCKRFILE_SPECIFIED=false
IMAGE_TAG_SPECIFIED=false
NOT_MOUNT=false
BUILD_IMAGE_SUCCESS=false

# Default values.
DISTRO=focal
CNOID_REPO=choreonoid/choreonoid
CNOID_TAG=master
GRASP_REPO=atsut97/graspPlugin
GRASP_TAG=master
IMAGE_REPO=grasp-plugin-dev
IMAGE_TAG=latest

# Variables made from user-specified values.
SHORT_CNOID_TAG=
IMAGE=
DOCKERFILE=

# Variables must be updated after parsing arguments.
update_vars() {
  # v1.7.0 -> 1.7
  SHORT_CNOID_TAG="$(echo $CNOID_TAG | sed 's/^v\([0-9.]\+\)\.0/\1/')"
  if [[ $IMAGE_TAG_SPECIFIED == false ]]; then
    IMAGE_TAG=${SHORT_CNOID_TAG}-${DISTRO}
  fi
  IMAGE=${IMAGE_REPO}:${IMAGE_TAG}
  if [[ $DOCKRFILE_SPECIFIED == false ]]; then
    DOCKERFILE="${script_dir}/${DISTRO}/Dockerfile"
  fi
}

script="$(realpath "$0")"
script_dir="$(dirname "$script")"
name="$(basename "$script")"

args=()
parse() {
  while (( "$#" )); do
    case "$1" in
      -h|--help)
        usage
        exit 0
        ;;
      -b|--build-only)
        BUILD_IMAGE=true
        RUN_CONTAINER=false
        shift
        ;;
      -r|--run-only)
        BUILD_IMAGE=false
        RUN_CONTAINER=true
        shift
        ;;
      -d|--dry-run)
        DRY_RUN=true
        shift
        ;;
      -f|--dockerfile)
        DOCKRFILE_SPECIFIED=true
        DOCKERFILE="$2"
        shift 2
        ;;
      -c|--cnoid-repo)
        CNOID_REPO="$2"
        shift 2
        ;;
      -g|--grasp-repo)
        GRASP_REPO="$2"
        shift 2
        ;;
      -G|--grasp-tag)
        GRASP_TAG="$2"
        shift 2
        ;;
      -M|--not-mount)
        NOT_MOUNT=true
        shift
        ;;
      -i|--image-name)
        IMAGE_REPO="${2%:*}"
        if [[ -n "${2##*:}" ]]; then
          IMAGE_TAG="${2##*:}"
          IMAGE_TAG_SPECIFIED=true
        fi
        shift 2
        ;;
      -t|--image-tag)
        IMAGE_TAG="$2"
        IMAGE_TAG_SPECIFIED=true
        shift 2
        ;;
      -*|--*)
        echo "error: unknown options $1" >&2
        exit 1
        ;;
      *)
        args+=("$1")
        shift
        ;;
    esac
  done
}

handle_args() {
  # Handle exceptions and set user-specified values.
  if [[ ${#args[@]} -lt 2 ]]; then
    echo "error: requires at least 2 arguments." >&2
    exit 1
  fi
  if [[ ":xenial:bionic:focal:" == *":${args[0]}:"* ]]; then
    DISTRO="${args[0]}"
  else
    echo "error: unknown distro: ${args[0]}" >&2
    exit 1
  fi
  CNOID_TAG="${args[1]}"
  update_vars
}

runcmd() {
  if [[ $DRY_RUN == true ]]; then
    echo "$@"
  else
    "$@"
  fi
  return $?
}

rename_tmux_window() {
  if [[ -n $(pgrep tmux) ]]; then
    runcmd tmux rename-window $IMAGE_TAG
  fi
}

build_docker_image() {
  local image=$1

  if [[ -f "$DOCKERFILE" ]]; then
    runcmd docker build --tag $image --file "$DOCKERFILE" \
           --build-arg CHOREONOID_REPO=$CNOID_REPO \
           --build-arg CHOREONOID_VER=$CNOID_TAG \
           "$script_dir"
    [ $? -eq 0 ] && BUILD_IMAGE_SUCCESS=true
  else
    echo "error: No such docker file: $DOCKERFILE" >&2
    return 1
  fi
}

docker_image_exists() {
  [[ -n $(docker images -q "$1") ]] && return 0 || return 1
}

run_docker_container() {
  local image=$1
  local mount_opt=

  if docker_image_exists $image; then
    if [[ $NOT_MOUNT = false ]]; then
      mount_opt='-v '"${script_dir}/graspPlugin":/opt/choreonoid/ext/graspPlugin
    fi
    runcmd docker run -it $mount_opt $image
  else
    echo "error: No such docker image: $IMAGE" >&2
    return 1
  fi
}

docker_container_running() {
  docker ps -q --filter status=running --filter ancestor=$1 --latest
}

exec_docker_container() {
  runcmd docker exec -it $1 /bin/bash
}

docker_container_exited() {
  docker ps -q --filter status=exited --filter ancestor=$1 --latest
}

start_docker_container() {
  runcmd docker start $1
}

restart_docker_container() {
  local image=$1
  local running=$(docker_container_running $image)
  local exited=$(docker_container_exited $image)

  if [[ -n $running ]]; then
    exec_docker_container $running
  elif [[ -n $exited ]]; then
    start_docker_container $exited
    exec_docker_container $exited
  else
    run_docker_container $image
  fi
}

# Main processes.
main() {
  # Parse optional arguments.
  parse "$@"

  # Handle arguments.
  handle_args

  # Rename tmux window name if running.
  rename_tmux_window

  # Build docker image.
  if [[ $BUILD_IMAGE == true ]]; then
    build_docker_image $IMAGE
  fi

  # Run docker container.
  if [[ $RUN_CONTAINER == true ]]; then
    if [[ $BUILD_IMAGE_SUCCESS == true ]]; then
      # Just when a new docker image is built.
      run_docker_container $IMAGE
    else
      # Otherwise restart a docker container based on the image.
      restart_docker_container $IMAGE
    fi
  fi
}

if [[ "${BASH_SOURCE[0]}" -ef "$0" ]]; then
  main "$@"
fi
