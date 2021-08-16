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
  Builds Docker image of Grasp Plugin for Choreonoid.

OPTIONS:
  -h, --help
    Show this message.

  -d, --dry-run
    Just print commands.

  -f, --dockerfile
    Specify Dockerfile.

  -b, --build-context
    Specify a directory on local machine as build context.

  -x, --buildx
    Build an image using BuildKit.

  -c, --cnoid-repo
    Specify Choreonoid repository. (Default: ${CNOID_REPO})

  -i, --image-name
    Specify Docker image repository name. (Default: ${IMAGE_REPO})

  -t, --image-tag
    Specify Docker image tag.

  -v, --verbose
    Verbose mode. Print debugging messages.

  <Distro>
    Ubuntu distro codename. Choose among xenial, bionic and focal.

  <Choreonoid tag>
    Specify Choreonoid released version.

EXAMPLES:
  1. Build Choreonoid with Grasp Plugin on Ubuntu 20.04.
        \$ $0 focal v1.7.0

  2. Build an image with a specific image name.
        \$ $0 --image-name grasp-test:bionic-1.7 bionic v1.7.0

  3. Build an image with a specific Dockerfile.
        \$ $0 -f ./xenial/Dockerfile.2 xenial v1.5.0

  4. Build an image with a different building context.
        \$ $0 --build-context . xenial v1.6.0
EOF
}

script="$(realpath "$0")"
script_dir="$(dirname "$script")"
root_dir="$(dirname "$script_dir")"
name="$(basename "$script")"

# Option flags.
DRY_RUN=false
DOCKRFILE_SPECIFIED=false
BUILD_CONTEXT_SPECIFIED=false
BUILDX=false
IMAGE_TAG_SPECIFIED=false
VERBOSE=false

# Default values.
DISTRO=focal
CNOID_REPO=choreonoid/choreonoid
CNOID_TAG=master
IMAGE_REPO=grasp-plugin-dev
IMAGE_TAG=latest

# Variables made from user-specified values.
SHORT_CNOID_TAG=
IMAGE=
DOCKERFILE=
BUILD_CONTEXT=

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
      -f|--dockerfile)
        DOCKRFILE_SPECIFIED=true
        DOCKERFILE="$2"
        shift 2
        ;;
      -b|--build-context)
        BUILD_CONTEXT_SPECIFIED=true
        BUILD_CONTEXT="$2"
        shift 2
        ;;
      -x|--buildx)
        BUILDX=true
        shift
        ;;
      -c|--cnoid-repo)
        CNOID_REPO="$2"
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
      -v|--verbose)
        VERBOSE=true
        shift
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
  # Handle exceptions and set user-specified values.
  if [[ ${#args[@]} -lt 2 ]]; then
    abort "Requires at least 2 arguments, but provided ${#args[@]}"
  fi

  DISTRO="${args[0]}"
  if [[ ! ":xenial:bionic:focal:" == *":${DISTRO}:"* ]]; then
    abort "Unknown distro: $DISTRO"
  fi

  # Get Choreonoid tag.
  # Ex. CNOID_TAG=v1.7.0
  #     SHORT_CNOID_TAG=1.7
  CNOID_TAG="${args[1]}"
  # shellcheck disable=SC2001
  SHORT_CNOID_TAG="$(echo "$CNOID_TAG" | sed 's/^v\([0-9.]\+\)\.0/\1/')"

  # Determine image name and its tag.
  if [[ $IMAGE_TAG_SPECIFIED == false ]]; then
    IMAGE_TAG=${SHORT_CNOID_TAG}-${DISTRO}
  fi
  IMAGE=${IMAGE_REPO}:${IMAGE_TAG}

  # Get Dockerfile and build context.
  if [[ $DOCKRFILE_SPECIFIED == false ]]; then
    DOCKERFILE="${root_dir}/${DISTRO}/Dockerfile"
  fi
  if [[ $BUILD_CONTEXT_SPECIFIED == false ]]; then
    BUILD_CONTEXT="${DOCKERFILE%/*}"
  fi

  # Debug messages.
  verbose "DISTRO: $DISTRO"
  verbose "CNOID_REPO: $CNOID_REPO"
  verbose "CNOID_TAG: $CNOID_TAG"
  verbose "SHORT_CNOID_TAG: $SHORT_CNOID_TAG"
  verbose "DOCKERFILE: $DOCKERFILE"
  verbose "BUILD_CONTEXT: $BUILD_CONTEXT"
  verbose "IMAGE_REPO: $IMAGE_REPO"
  verbose "IMAGE_TAG: $IMAGE_TAG"
  verbose "IMAGE: $IMAGE"
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

docker_build() {
  local image=$1
  local buildx_flag=

  require_n_args 1 $#
  if [[ $BUILDX == true ]]; then
    buildx_flag="buildx"
  fi
  if [[ -f "$DOCKERFILE" ]]; then
    # debug messages
    verbose "Building Docker Image with the following command:"
    verbose "docker ${buildx_flag} build \\"
    verbose "    --tag $image \\"
    verbose "    --file $DOCKERFILE \\"
    verbose "    --build-arg CHOREONOID_REPO=$CNOID_REPO \\"
    verbose "    --build-arg CHOREONOID_TAG=$CNOID_TAG \\"
    verbose "    $BUILD_CONTEXT"

    runcmd docker "$buildx_flag" build \
           --tag "$image" \
           --file "$DOCKERFILE" \
           --build-arg CHOREONOID_REPO="$CNOID_REPO" \
           --build-arg CHOREONOID_TAG="$CNOID_TAG" \
           "$BUILD_CONTEXT"
  else
    abort "No such Dockerfile: $DOCKERFILE"
  fi
}

# Main processes.
main() {
  # Parse optional arguments.
  parse "$@"

  # Handle arguments.
  handle_args

  # Check if Docker daemon is runnig.
  docker_is_running || exit 1

  # Build docker image.
  docker_build "$IMAGE"
}

if [[ "${BASH_SOURCE[0]}" -ef "$0" ]]; then
  main "$@"
fi
