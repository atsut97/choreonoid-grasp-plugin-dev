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
RUN_NEW_CONTAINER=false
SHOW_LIST=false
VERBOSE=false

# Default values.
CNOID_TAG=master
GRASP_PLUGIN_PATH="${root_dir}/graspPlugin"
IMAGE_REPO=grasp-plugin-dev
IMAGE_TAG=

# Variables made from user-specified values.
DISTRO=
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
      -i|--image-name|--image-repo)
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
  local cmds=()

  # Remove empty string from the arguments.
  for i in "$@"; do
    [[ -n "$i" ]] && cmds+=("$i")
  done

  if [[ $DRY_RUN == true ]]; then
    echo "${cmds[@]}"
  else
    "${cmds[@]}"
  fi
  return $?
}

MSG_STACK_OFFSET=0
_msg_header() {
  # This internal function is designed to be called inside debbuging
  # functions such as abort() and verbose().
  local msgtype=${1:-note}
  local sourcefile
  local sourcedir
  local prefix
  declare -i n
  n=${MSG_STACK_OFFSET}+1

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
    echo "${sourcefile}:${BASH_LINENO[$n]}: in ${FUNCNAME[$n+1]}(): ${msgtype}:"
  fi
  MSG_STACK_OFFSET=0
}

error() {
  echo >&2 "$(_msg_header error)" "$@"
}

abort() {
  echo >&2 "$(_msg_header error)" "$@"
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

require_n_args() {
  local expected=$1
  local actual=$2
  declare -a frame

  IFS=" " read -r -a frame <<< "$(caller 1)"
  if [[ $expected -gt $actual ]]; then
    MSG_STACK_OFFSET=1
    abort "Requires $expected arguments, but provided $actual. Called from #${frame[0]} in ${frame[1]}()"
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

  # Debug messages.
  verbose "DISTRO: $DISTRO"
  verbose "CNOID_TAG: $CNOID_TAG"
  verbose "SHORT_CNOID_TAG: $SHORT_CNOID_TAG"
  verbose "GRASP_PLUGIN_PATH: $GRASP_PLUGIN_PATH"
  verbose "CONTAINER: $CONTAINER"
  verbose "IMAGE_REPO: $IMAGE_REPO"
  verbose "IMAGE_TAG: $IMAGE_TAG"
  verbose "IMAGE: $IMAGE"
  verbose "RUN_ARGS[${#RUN_ARGS[@]}]: ${RUN_ARGS[*]}"
}

tmux_is_running() {
  if [[ -n $(pgrep tmux) ]]; then
    return 0
  else
    return 1
  fi
}

tmux_rename_window() {
  require_n_args 1 $#
  if tmux_is_running; then
    runcmd tmux rename-window "$1"
  fi
}

docker_is_running() {
  if ! command -v docker >/dev/null 2>&1; then
    error "Unable to find docker on the system"
    return 1
  elif ! docker stats --no-stream >/dev/null 2>&1; then
    error "Cannot connect to Docker daemon"
    return 1
  else
    return 0
  fi
}

# Returns container's short ID if found, otherwise returns an empty
# string.
docker_container_get_id() {
  local container=$1
  local id

  require_n_args 1 $#
  # Try to find by container name.
  id=$(docker ps --all --quiet --filter name=^/"${container}"\$)
  if [[ -z "$id" ]]; then
    # Try to find by container ID.
    id=$(docker ps --all --quiet --filter id="${container}")
  fi
  echo "$id"
}

docker_container_exists() {
  require_n_args 1 $#
  if [[ -n $(docker_container_get_id "$1") ]]; then
    return 0
  else
    return 1
  fi
}

docker_container_ensure_exist() {
  require_n_args 1 $#
  docker_container_exists "$1" || abort "No such container: $1"
}

docker_container_get_status() {
  local container=$1
  local id

  docker_container_ensure_exist "$container"
  id=$(docker_container_get_id "$container")
  docker container inspect --format='{{.State.Status}}' "$id"
}

docker_container_get_tag() {
  local container=$1
  local id

  docker_container_ensure_exist "$container"
  id=$(docker_container_get_id "$container")
  docker container inspect --format='{{.Image}}' "$id"
}

docker_container_is_running() {
  local container=$1
  local id

  docker_container_ensure_exist "$container"
  if [[ $(docker_container_get_status "$container") == running ]]; then
    return 0
  else
    return 1
  fi
}

docker_container_is_exited() {
  local container=$1
  local id

  docker_container_ensure_exist "$container"
  if [[ $(docker_container_get_status "$container") == exited ]]; then
    return 0
  else
    return 1
  fi
}

docker_exec_container() {
  local container=$1

  verbose "Command: docker exec -it $container /bin/bash"
  runcmd docker exec -it "$container" /bin/bash
}

docker_start_container() {
  local container=$1
  local status
  local started

  verbose "Command: docker start '$container'"
  runcmd docker start "$container"
  # Wait until the container has started.
  started=false
  # shellcheck disable=SC2034
  for i in {1..3}; do
    status=$(docker_container_get_status "$container")
    verbose "Container status: $status"
    if [[ $status == running || $DRY_RUN == true ]]; then
      started=true
      break
    fi
    verbose "Waiting to start: '$container'"
    sleep 1
  done
  if [[ $started == false ]]; then
    abort "Cannot start container: $container"
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
  verbose "Looking for an image filtered by 'reference=$reference'"
  image_id=$(docker images --quiet --filter "reference=$reference" | head -n 1)
  # Get a string whose format is repository:tag.
  if [[ -n $image_id ]]; then
    verbose "Found an image: image_id=$image_id"
    output=$(docker image inspect "$image_id" --format "{{index .RepoTags 0}}")
  else
    verbose "Found no images with filter 'reference=$reference'"
  fi
  # Just echo the variable is redundant, I know. This is for ease of
  # debugging.
  verbose "Estimated most likely image name is '$output'"
  echo "$output"
}

docker_image_exists() {
  require_n_args 1 $#
  if [[ -n $(docker images --quiet "$1") ]]; then
    return 0
  else
    return 1
  fi
}

docker_image_ensure_exist() {
  require_n_args 1 $#
  docker_image_exists "$1" || abort "No such image: $1"
}

docker_image_get_container_id() {
  local image=$1
  local id

  require_n_args 1 $#
  docker_image_ensure_exist "$image"
  # Try to find container based on the given image.
  id=$(docker ps --all --quiet --filter ancestor="$image" --latest)
  echo "$id"
}

docker_run_container() {
  local image=$1
  local args=()
  local opts=()

  shift; args=("$@")
  opts+=("-it")
  if docker_image_exists "$image"; then
    if [[ $DO_MOUNT == true ]]; then
      verbose "Mount volume ${GRASP_PLUGIN_PATH} to /opt/choreonoid/ext/graspPlugin"
      opts+=("-v" "${GRASP_PLUGIN_PATH}:/opt/choreonoid/ext/graspPlugin")
    fi
    verbose "Command: docker run ${opts[*]}"
    runcmd docker run "${opts[@]}" "$image" "${args[@]}"
  else
    abort "No such docker image: $image"
  fi
}

docker_resume_container() {
  local container=$1

  require_n_args 1 $#
  docker_container_ensure_exist "$container"
  if [[ -z "$IMAGE_TAG" ]]; then
    IMAGE_TAG=$(docker_container_get_tag "$container")
    tmux_rename_window "$IMAGE_TAG"
  fi
  if docker_container_is_exited "$container"; then
    verbose "Container '$container' is stopped. Starting it."
    docker_start_container "$container"
  fi
  if docker_container_is_running "$container"; then
    verbose "Container '$container' is running. Diving into it."
    docker_exec_container "$container"
  else
    abort "Cannot handle the current status: $(docker_container_get_status "$container")"
  fi
}

run() {
  local container
  local image

  if [[ -n "$CONTAINER" ]]; then
    # When a specific container is providied with the '--container'
    # option, resume the container.
    verbose "Trying to resume user-specified container '$CONTAINER'"
    docker_resume_container "$CONTAINER"
  else
    # Estimate the most likely Docker image to be run from the
    # provided arguments and options such as '--image-name' and
    # '--image-tag'.
    verbose "Estimating most likely image from '$IMAGE_REPO' and '$IMAGE_TAG'"
    image=$(docker_image_estimate_name "$IMAGE_REPO" "$IMAGE_TAG")
    if [[ -n "$image" ]]; then
      verbose "Estimated image is '$image'"
      if [[ $RUN_NEW_CONTAINER == true ]]; then
        # When the option '--new' is specified, run a new container
        # based on the estimated image.
        verbose "Running a new container based on '$image'"
        docker_run_container "$image" "${RUN_ARGS[@]}"
      else
        # Look for a container running or exited based on the
        # estimated image.
        verbose "Looking for a container whose ancestor is '$image'"
        container=$(docker_image_get_container_id "$image")
        if [[ -n "$container" ]]; then
          # If a container based on the estimated image exists on the
          # host machine, try to resume the container.
          verbose "Trying to resume existing container '$container'"
          docker_resume_container "$container"
        else
          # If no container based on the estimated image is found, run
          # a new container based on that.
          verbose "No container is found. Running a new container based on '$image'"
          docker_run_container "$image" "${RUN_ARGS[@]}"
        fi
      fi
    else
      # As estimating the most likely Docker image is failed, abort
      # this script.
      abort "Could not find any Docker image available. Please specify a specific image name with the '--image-name' option."
    fi
  fi
}

list() {
  local reference
  local candidates
  local filters

  reference="${IMAGE_REPO}${IMAGE_TAG:+:}${IMAGE_TAG}"
  candidates=()
  mapfile -t candidates < <(docker images --quiet --filter "reference=$reference")

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

# Main processes.
main() {
  # Parse optional arguments.
  parse "$@"

  # Handle arguments.
  handle_args

  # Check if Docker daemon is runnig.
  docker_is_running || exit 1

  if [[ $SHOW_LIST == true ]]; then
    # Show list of containers and images.
    list
  else
    # Rename tmux window
    tmux_rename_window "$IMAGE_TAG"

    # Run the main process.
    run
  fi
}

if [[ "${BASH_SOURCE[0]}" -ef "$0" ]]; then
  main "$@"
fi
