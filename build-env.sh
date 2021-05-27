#! /usr/bin/env bash

set -eux -o pipefail

usage() {
  echo "Usage:"
  echo "  $0 [options] <distro> <choreonoid-version>"
  echo ""
  echo "Options:"
  echo "  --build-only    Build docker image then exit."
  echo ""
  echo "Example:"
  echo "  $0 xenial v1.5.0"
  echo "  $0 --build-only bionic v1.7.0"
}

if [[ $# -lt 2 ]]; then
  usage
  exit 1
fi

BUILD_ONLY=FALSE
if [[ $1 = "--build-only" ]]; then
  BUILD_ONLY=TRUE
  shift
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
DISTRO=$1
CHOREONOID_VER=$2
SHORT_CHOREONOID_VER=$(echo $CHOREONOID_VER | sed 's/^v\([0-9.]\+\)\.0/\1/')
REPOSITORY=grasp-plugin-dev
TAG=${SHORT_CHOREONOID_VER}-${DISTRO}
IMAGE=${REPOSITORY}:${TAG}
DOCKERFILE="${SCRIPT_DIR}/${DISTRO}/Dockerfile"

tmux rename-window $TAG
docker build --tag $IMAGE --file "${DOCKERFILE}" --build-arg CHOREONOID_VER=${CHOREONOID_VER} "${SCRIPT_DIR}"
if [[ $BUILD_ONLY == FALSE ]]; then
  docker run -it -v "${SCRIPT_DIR}/graspPlugin:/opt/choreonoid/ext/graspPlugin" $IMAGE /bin/bash
fi
