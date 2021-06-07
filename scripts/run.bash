#!/usr/bin/env bash

set -e
set -o pipefail

usage() {
  cat <<EOF
NAME:
  $name

SYNOPSIS:
  $0 [options] [<Distro>] [<Choreonoid tag>]

DESCRIPTION:
  Runs a Docker container based on the image of Grasp Plugin.

OPTIONS:
  -h, --help
    Show this message.

  -d, --dry-run
    Just print commands.

  -c, --cnoid-repo
    Specify Choreonoid repository. (Default: ${CNOID_REPO})

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
DRY_RUN=false
IMAGE_TAG_SPECIFIED=false
NOT_MOUNT=false

# Default values.
DISTRO=focal
CNOID_REPO=choreonoid/choreonoid
CNOID_TAG=master
IMAGE_REPO=grasp-plugin-dev
IMAGE_TAG=latest

# Variables made from user-specified values.
SHORT_CNOID_TAG=
IMAGE=

# Variables must be updated after parsing arguments.
update_vars() {
  # shellcheck disable=SC2001
  # ex. v1.7.0 -> 1.7
  SHORT_CNOID_TAG="$(echo $CNOID_TAG | sed 's/^v\([0-9.]\+\)\.0/\1/')"
  if [[ $IMAGE_TAG_SPECIFIED == false ]]; then
    IMAGE_TAG=${SHORT_CNOID_TAG}-${DISTRO}
  fi
  IMAGE=${IMAGE_REPO}:${IMAGE_TAG}
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
      -d|--dry-run)
        DRY_RUN=true
        shift
        ;;
      -c|--cnoid-repo)
        CNOID_REPO="$2"
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
      -*)
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

is_tmux_running() {
  if [[ -n $(pgrep tmux) ]]; then
    return 0
  else
    return 1
  fi
}

rename_tmux_window() {
  local name=$1
  if is_tmux_running; then
    runcmd tmux rename-window "$name"
  fi
}

docker_image_exists() {
  if [[ -n $(docker images -q "$1") ]]; then
    return 0
  else
    return 1
  fi
}

run_docker_container() {
  local image=$1
  local mount_opt=

  if docker_image_exists "$image"; then
    if [[ $NOT_MOUNT = false ]]; then
      mount_opt='-v '"${script_dir}/graspPlugin":/opt/choreonoid/ext/graspPlugin
    fi
    runcmd docker run -it "$mount_opt" "$image"
  else
    echo "error: No such docker image: $IMAGE" >&2
    return 1
  fi
}

docker_container_running() {
  docker ps -q --filter status=running --filter ancestor="$1" --latest
}

exec_docker_container() {
  runcmd docker exec -it "$1" /bin/bash
}

docker_container_exited() {
  docker ps -q --filter status=exited --filter ancestor="$1" --latest
}

start_docker_container() {
  runcmd docker start "$1"
}

restart_docker_container() {
  local image=$1
  local running exited
  running=$(docker_container_running "$image")
  exited=$(docker_container_exited "$image")

  if [[ -n $running ]]; then
    exec_docker_container "$running"
  elif [[ -n $exited ]]; then
    start_docker_container "$exited"
    exec_docker_container "$exited"
  else
    run_docker_container "$image"
  fi
}

# Main processes.
main() {
  # Parse optional arguments.
  parse "$@"

  # Handle arguments.
  handle_args

  # Rename tmux window name if running.
  rename_tmux_window "$IMAGE_TAG"

  # Run docker container.
  if [[ $RUN_CONTAINER == true ]]; then
    if [[ $BUILD_IMAGE_SUCCESS == true ]]; then
      # Just when a new docker image is built.
      run_docker_container "$IMAGE"
    else
      # Otherwise restart a docker container based on the image.
      restart_docker_container "$IMAGE"
    fi
  fi
}

if [[ "${BASH_SOURCE[0]}" -ef "$0" ]]; then
  main "$@"
fi
