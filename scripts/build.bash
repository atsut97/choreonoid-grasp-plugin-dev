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

  -c, --cnoid-repo
    Specify Choreonoid repository. (Default: ${CNOID_REPO})

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
DOCKRFILE_SPECIFIED=false
IMAGE_TAG_SPECIFIED=false

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

script="$(realpath "$0")"
script_dir="$(dirname "$script")"
root_dir="$(dirname "$script_dir")"
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
      -f|--dockerfile)
        DOCKRFILE_SPECIFIED=true
        DOCKERFILE="$2"
        shift 2
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

  # Get Dockerfile.
  if [[ $DOCKRFILE_SPECIFIED == false ]]; then
    DOCKERFILE="${root_dir}/${DISTRO}/Dockerfile"
  fi
}

runcmd() {
  if [[ $DRY_RUN == true ]]; then
    echo "$@"
  else
    "$@"
  fi
  return $?
}

build_docker_image() {
  local image=$1

  if [[ -f "$DOCKERFILE" ]]; then
    runcmd docker build --tag "$image" --file "$DOCKERFILE" \
           --build-arg CHOREONOID_REPO="$CNOID_REPO" \
           --build-arg CHOREONOID_TAG="$CNOID_TAG" \
           "$root_dir"
  else
    echo "error: No such docker file: $DOCKERFILE" >&2
    return 1
  fi
}

# Main processes.
main() {
  # Parse optional arguments.
  parse "$@"

  # Handle arguments.
  handle_args

  # Build docker image.
  build_docker_image "$IMAGE"
}

if [[ "${BASH_SOURCE[0]}" -ef "$0" ]]; then
  main "$@"
fi
