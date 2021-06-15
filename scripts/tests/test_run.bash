#!/usr/bin/env bash

set -e

this_script="$(realpath "$0")"
scripts_dir="${this_script%/*/*}"
target="${scripts_dir}/run.bash"

# Utility functions.
copy_func() {
  test -n "$(declare -f "$1")" || return
  eval "${_/$1 ()/$2 ()}"
}

rename_func() {
  copy_func "$@" || return
  unset -f "$1"
}

# Mock function for tmux command.
tmux () {
  :
}
export -f tmux

# Mock function for docker command.
docker () {
  case $1 in
    ps)
      shift
      _docker_ps "$@"
      ;;
    images)
      shift
      _docker_images "$@"
      ;;
    container)
      shift
      _docker_container "$@"
      ;;
    image)
      shift
      _docker_image "$@"
      ;;
    start)
      shift
      _docker_start "$@"
      ;;
    exec)
      shift
      _docker_exec "$@"
      ;;
    run)
      shift
      _docker_run "$@"
      ;;
    stat)
      shift
      _docker_stat "$@"
      ;;
    *)
      echo >&2 "Unhandled Docker subcommand: $1"
      return 1
      ;;
  esac
}
export -f docker

_docker_ps() {
  :
}
export -f _docker_ps

_docker_images() {
  :
}
export -f _docker_images

_docker_container() {
  :
}
export -f _docker_container

_docker_image() {
  :
}
export -f _docker_image

_docker_start() {
  echo "docker start" "$@"
}
export -f _docker_start

_docker_exec() {
  echo "docker exec" "$@"
}
export -f _docker_exec

_docker_run() {
  echo "docker run" "$@"
}
export -f _docker_run

_docker_stat() {
  :
}
_docker_stat_default() {
  return 0
}
export -f _docker_stat

# test case: abort when docker is not running
_docker_stat_return_1() {
  return 1
}
copy_func _docker_stat_return_1 _docker_stat
$target || echo "successfully abort"
copy_func _docker_stat_default _docker_stat

# test case: abort when unrecognized distro is given
$target unknown_os || echo "successfully abort"

# test case: abort when non-existent container is given
$target --container unknown_container || echo "successfully abort"

# test case: abort when non-existent image is given
$target --image-name unknown_image || echo "successfully abort"

echo "Complete!"
