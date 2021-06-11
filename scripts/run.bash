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

  -m, --mount
    Specify whether mount directory on host machine into container or
    not. This accepts optional argument true or false.
    (Default: ${DO_MOUNT})

  -g, --glusp-plugin
    Directory path that contains sources of grasp plugin to mount into
    container. This value is ignored when supplying --mount=false.
    (Default: ${GRASP_PLUGIN_PATH})

  -i, --image-name
    Specify Docker image repository name. (Default: ${IMAGE_REPO})

  -t, --image-tag
    Specify Docker image tag.

  -c, --container
    Specify Docker container ID or name.

  -n, --new
    Run a new container based on the specified image.

  -a, --args
    Arguments that are passed to the entrypoint script in the
    container.

  -l, --list
    List containers that are running or stopped and built images.

  -v, --verbose
    Verbose mode. Print debugging messages.

  <Distro>
    Ubuntu distro codename. Choose among xenial, bionic and focal.

  <Choreonoid tag>
    Specify Choreonoid released version.

EXAMPLES:
  1. Run a new container that includes Choreonoid v1.7.0 with Grasp
     Plugin on Ubuntu 20.04 and execute build commands.
        \$ $0 --new focal v1.7.0 --args build

  2. Run the latest exited container based on the image that includes
     specific version of Choreonid and Grasp plugin.
        \$ $0 xenial v1.5.0

  3. List containers that are running aor exited.
        \$ $0 --list

  4. Run a new container whose image is the latest.
        \$ $0 --new

  5. Run the latest exited container. When none of such contaniers is
     available, create a new one.
        \$ $0
EOF
}

script="$(realpath "$0")"
script_dir="$(dirname "$script")"
root_dir="$(dirname "$script_dir")"
name="$(basename "$script")"

# Option flags.
DRY_RUN=false
IMAGE_TAG_SPECIFIED=false
DO_MOUNT=true
GRASP_PLUGIN_PATH="${root_dir}/graspPlugin"
RUN_NEW_CONTAINER=false
SHOW_LIST=false
VERBOSE=false

# Default values.
DISTRO=
CNOID_TAG=master
IMAGE_REPO=grasp-plugin-dev
IMAGE_TAG=latest

# Variables made from user-specified values.
SHORT_CNOID_TAG=
IMAGE=
CONTAINER=
RUN_ARGS=()

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
      -m|--mount*)
        if [[ "$1" == -m || "$1" == --mount ]]; then
          DO_MOUNT=true
          if [[ "$2" == true || "$2" == false ]]; then
            DO_MOUNT="$2"
            shift
          fi
        elif [[ "$1" == --mount=* ]]; then
          DO_MOUNT="${1#*=}"
        fi
        shift
        ;;
      -g|--grasp-plugin)
        GRASP_PLUGIN_PATH="$2"
        shift 2
        ;;
      -i|--image-name)
        IMAGE_REPO="${2%:*}"
        if [[ $2 == *:* ]]; then
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
      -c|--container)
        CONTAINER="$2"
        shift 2
        ;;
      -n|--new)
        RUN_NEW_CONTAINER=true
        shift
        ;;
      -l|--list)
        SHOW_LIST=true
        shift
        ;;
      -a|--args)
        shift
        while (( "$#" )); do
          case "$1" in
            --|-?*)
              break
              ;;
            *)
              RUN_ARGS+=("$1")
              shift
              ;;
          esac
        done
        ;;
      -v|--verbose)
        VERBOSE=true
        shift
        ;;
      --)
        shift
        args+=("$@")
        shift "$#"
        ;;
      -?*)
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

runcmd() {
  if [[ $DRY_RUN == true ]]; then
    echo "$@"
  else
    "$@"
  fi
  return $?
}

_msg_header() {
  # This internal function is designed to be called inside debbuging
  # functions such as abort() and verbose().
  local msgtype=${1:-note}
  local sourcefile
  local sourcedir
  local prefix

  if [[ $VERBOSE == false ]]; then
    echo "${msgtype}:"
  else
    sourcedir="${BASH_SOURCE[0]%/*}"
    if [[ ${#sourcedir} -gt 16 ]]; then
      prefix="${sourcedir:0:6}"
      prefix="${prefix}...${sourcedir:(-6)}"
    else
      prefix="$sourcedir"
    fi
    [[ -n "$prefix" ]] && prefix="${prefix}/"
    sourcefile="${prefix}${BASH_SOURCE[0]##*/}"
    echo "${sourcefile}:${BASH_LINENO[1]}: in ${FUNCNAME[2]}(): ${msgtype}:"
  fi
}

error() {
  echo >&2 "$(_msg_header error)" "$@"
}

abort() {
  error "$@"
  [[ $DRY_RUN == true ]] && exit 0 || exit 1
}

warning() {
  echo >&2 "$(_msg_header warning)" "$@"
}

verbose() {
  if [[ $VERBOSE == true ]]; then
    echo >&2 "$(_msg_header note)" "$@"
  fi
}

handle_args() {
  # Check specified distro name. If nothing specified keep it empty.
  DISTRO="${args[0]}"
  if [[ -n $DISTRO && ! ":xenial:bionic:focal:*:" == *":${DISTRO}:"* ]]; then
    abort "Unknown distro: $DISTRO"
  fi

  # Get Choreonoid tag. If nothing given keep it empty.
  # Ex. CNOID_TAG=v1.7.0
  #     SHORT_CNOID_TAG=1.7
  CNOID_TAG="${args[1]}"
  # shellcheck disable=SC2001
  SHORT_CNOID_TAG="$(echo "$CNOID_TAG" | sed 's/^v\([0-9.]\+\)\.0/\1/')"

  # Determine image tag reference for filtering.
  if [[ $IMAGE_TAG_SPECIFIED == false ]]; then
    if [[ -z $DISTRO || ("$DISTRO" == "*" && -z $CNOID_TAG) ]]; then
      IMAGE_TAG=
    else
      IMAGE_TAG="${SHORT_CNOID_TAG:-*}-${DISTRO}"
    fi
  fi
}

tmux_is_running() {
  if [[ -n $(pgrep tmux) ]]; then
    return 0
  else
    return 1
  fi
}

tmux_rename_window() {
  local name=$1
  if tmux_is_running; then
    runcmd tmux rename-window "$name"
  fi
}

# Returns container's short ID if found, otherwise returns an empty
# string.
docker_container_get_id() {
  local container=$1
  local id

  if [[ $# -eq 0 ]]; then
    abort "docker_get_container_id: requires at least 1 argument"
  fi

  # Try to find by container name.
  id=$(docker ps --all --filter name=^/"${container}"\$)
  if [[ -z "$id" ]]; then
    # Try to find by container ID.
    id=$(docker ps --all --filter id="${container}")
  fi
  echo "$id"
}

docker_container_exists() {
  if [[ -n $(docker_get_container_id "$1") ]]; then
    return 0
  else
    return 1
  fi
}

docker_container_get_status() {
  local container=$1
  local id

  if [[ $# -eq 0 ]]; then
    abort "docker_container_get_status: requires at least 1 argument"
  fi
  if ! docker_container_exists "$container"; then
    abort "docker_container_get_status: no such container: $container"
  fi

  id=$(docker_get_container_id "$container")
  docker container inspect --format='{{.State.Status}}' "$id"
}

docker_container_is_running() {
  local container=$1
  local id

  if [[ $# -eq 0 ]]; then
    abort "docker_container_is_running: requires at least 1 argument"
  fi
  if ! docker_container_exists "$container"; then
    abort "docker_container_is_running: no such container: $container"
  fi

  if [[ $(docker_container_get_status "$container") == running ]]; then
    return 0
  else
    return 1
  fi
}

docker_container_is_exited() {
  local container=$1
  local id

  if [[ $# -eq 0 ]]; then
    abort "docker_container_is_exited: requires at least 1 argument"
  fi
  if ! docker_container_exists "$container"; then
    abort "docker_container_is_exited: no such container: $container"
  fi

  if [[ $(docker_container_get_status "$container") == exited ]]; then
    return 0
  else
    return 1
  fi
}

docker_exec_container() {
  local container=$1

  runcmd docker exec -it "$1" /bin/bash >/dev/null
}

docker_start_container() {
  local container=$1
  local status
  local started

  runcmd docker start "$container" >/dev/null
  # Wait until the container has started.
  started=false
  # shellcheck disable=SC2034
  for i in {1..3}; do
    status=$(docker_container_get_status "$container")
    if [[ $status == running || $DRY_RUN == true ]]; then
      started=true
      break
    fi
    sleep 1
  done
  if [[ $started == false ]]; then
    abort "docker_start_container: cannot start container: $container"
  fi
}

# Returns a string which consists of the most likely image repository
# and tag, for example, grasp-plugin-dev:1.7-focal. What we mean by
# "the most likely" is that the most recently created image is chosen
# among those match the given repository name and optionally the given
# tag.
docker_image_estimate_name() {
  local repo=$1
  local tag=$2
  local reference
  local image_id
  local output

  # Create reference string from arguments.
  reference="${repo}${tag:+:}${tag}"
  image_id=$(docker images --quiet --filter "reference=$reference" | head -n 1)
  # Get a string whose format is repository:tag.
  if [[ -n $image_id ]]; then
    output=$(docker image inspect "$image_id" --format "{{index .RepoTags 0}}")
  fi
  # Just echo the variable is redundant, I know. This is for ease of
  # debugging.
  echo "$output"
}

docker_image_exists() {
  if [[ -n $(docker images --quiet "$1") ]]; then
    return 0
  else
    return 1
  fi
}

docker_image_get_container_id() {
  local image=$1
  local id

  if [[ $# -eq 0 ]]; then
    abort "docker_image_get_container_id: requires at least 1 argument"
  fi
  if ! docker_image_exists "$image"; then
    abort "docker_image_get_container_id: no such image: $image"
  fi

  # Try to find container based on the given image.
  id=$(docker ps --all --quiet --filter ancestor="$image" --latest)
  echo "$id"
}

docker_run_container() {
  local image=$1
  local opts=()

  opts+=("-it")
  if docker_image_exists "$image"; then
    if [[ $DO_MOUNT == true ]]; then
      opts+=("-v" "${GRASP_PLUGIN_PATH}:/opt/choreonoid/ext/graspPlugin")
    fi
    runcmd docker run "${opts[@]}" >/dev/null
  else
    abort "docker_run_container: no such docker image: $image"
  fi
}

docker_resume_container() {
  local container=$1

  if [[ $# -eq 0 ]]; then
    abort "docker_resume_container: requires at least 1 argument"
  fi
  if ! docker_container_exists "$container"; then
    abort "docker_resume_container: no such container: $container"
  fi

  if docker_container_is_exited "$container"; then
    docker_start_container "$container"
  fi
  if docker_container_is_running "$container"; then
    docker_exec_container "$container"
  else
    abort "docker_resume_container: cannot handle the current status: $(docker_container_get_status)"
  fi
}

run() {
  local container
  local image

  if [[ -n "$CONTAINER" ]]; then
    # When a specific container is providied with the '--container'
    # option, resume the container.
    docker_resume_container "$CONTAINER"
  else
    # Estimate the most likely Docker image to be run from the
    # provided arguments and options such as '--image-name' and
    # '--image-tag'.
    image=$(docker_image_estimate_name "$IMAGE_REPO" "$IMAGE_TAG")
    if [[ -n "$image" ]]; then
      if [[ $RUN_NEW_CONTAINER == true ]]; then
        # When the option '--new' is specified, run a new container
        # based on the estimated image.
        docker_run_container "$image"
      else
        # Look for a container running or exited based on the
        # estimated image.
        container=$(docker_image_get_container_id "$image")
        if [[ -n "$container" ]]; then
          # If a container based on the estimated image exists on the
          # host machine, try to resume the container.
          docker_resume_container "$container"
        else
          # If no container based on the estimated image is found, run
          # a new container based on that.
          docker_run_container "$image"
        fi
      fi
    else
      # As estimating the most likely Docker image is failed, abort
      # this script.
      abort "run: Could not find any Docker image available. Please specify a specific image name with the '--image-name' option."
    fi
  fi
}

list() {
  local reference
  local candidates
  local filters

  reference="${IMAGE_REPO}${IMAGE_TAG:+:}${IMAGE_TAG}"
  candidates=()
  readarray -t candidates < <(docker images --quiet --filter "reference=$reference")

  # Show running and stopped containers based on possible images.
  filters=()
  for i in "${candidates[@]}"; do
    filters+=("--filter" "ancestor=$i")
  done
  docker ps --all "${filters[@]}"
  echo "--"
  # Show top level images filtered by provided arguments and options.
  docker images --filter "reference=$reference"
}

debug() {
  echo "======="
  echo "script=$script"
  echo "script_dir=$script_dir"
  echo "root_dir=$root_dir"
  echo "name=$name"
  echo "--"
  echo "DRY_RUN=$DRY_RUN"
  echo "IMAGE_TAG_SPECIFIED=$IMAGE_TAG_SPECIFIED"
  echo "DO_MOUNT=$DO_MOUNT"
  echo "GRASP_PLUGIN_PATH=$GRASP_PLUGIN_PATH"
  echo "RUN_NEW_CONTAINER=$RUN_NEW_CONTAINER"
  echo "--"
  echo "DISTRO=$DISTRO"
  echo "CNOID_TAG=$CNOID_TAG"
  echo "IMAGE_REPO=$IMAGE_REPO"
  echo "IMAGE_TAG=$IMAGE_TAG"
  echo "--"
  echo "SHORT_CNOID_TAG=$SHORT_CNOID_TAG"
  echo "IMAGE=$IMAGE"
  echo "CONTAINER=$CONTAINER"
  echo "RUN_ARGS[${#RUN_ARGS[@]}]=${RUN_ARGS[*]}"
  echo "args[${#args[@]}]=${args[*]}"
  echo "--"
}

# Main processes.
main() {
  # Parse optional arguments.
  parse "$@"

  # Handle arguments.
  handle_args

  if [[ $SHOW_LIST == true ]]; then
    # Show list of containers and images.
    list
  else
    # Run the main process.
    run
  fi
}

if [[ "${BASH_SOURCE[0]}" -ef "$0" ]]; then
  main "$@"
fi
