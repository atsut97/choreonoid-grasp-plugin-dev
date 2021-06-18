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
    stats)
      shift
      _docker_stats "$@"
      ;;
    *)
      echo >&2 "Unhandled Docker subcommand: $1"
      return 1
      ;;
  esac
}
export -f docker

IMAGE_LIST=$(cat <<'EOF'
REPOSITORY         TAG          IMAGE ID       CREATED        SIZE
grasp-plugin-dev   1.7-focal    67314cfd8d4c   6 days ago     2.44GB
grasp-plugin-dev   1.7-bionic   533852bf9da0   6 days ago     2GB
grasp-plugin-dev   1.5-xenial   439adde29d8d   6 days ago     1.91GB
grasp-plugin-dev   1.6-xenial   91cded17a5d1   6 days ago     1.93GB
grasp-plugin-dev   1.7-xenial   5c29cc2f42eb   7 days ago     1.94GB
EOF
)
export IMAGE_LIST

CONTAINER_LIST=$(cat <<'EOF'
CONTAINER ID   IMAGE                         COMMAND                   CREATED          STATUS                      PORTS     NAMES
ccf685315d94   grasp-plugin-dev:1.6-xenial   "/docker-entrypoint.…"   3 minutes ago    Up 3 minutes                          laughing_pare
7581a090cbd8   grasp-plugin-dev:1.5-xenial   "/docker-entrypoint.…"   6 minutes ago    Up 6 minutes                          affectionate_poitras
7ae8180e0c70   grasp-plugin-dev:1.5-xenial   "/docker-entrypoint.…"   8 minutes ago    Exited (1) 7 minutes ago              epic_darwin
905da50fc5fd   grasp-plugin-dev:1.5-xenial   "/docker-entrypoint.…"   9 minutes ago    Exited (0) 8 minutes ago              strange_goldwasser
EOF
)
export CONTAINER_LIST


_docker_ps_default() {
  local filter
  local quiet=0
  while (( "$#" )); do
    case "$1" in
      --quiet)
        quiet=1
        shift
        ;;
      --filter)
        filter="$2"
        shift 2
        ;;
      *)
        shift
        ;;
    esac
  done

  # local key="${filter%=*}"
  local value="${filter#*=}"
  local header
  local lines
  header=$(echo "$CONTAINER_LIST" | head -n 1)
  if [[ -n "$filter" ]]; then
    mapfile -t lines < <(echo "$CONTAINER_LIST" | grep -E "$value" | head -n 1)
  else
    mapfile -t lines < <(echo "$CONTAINER_LIST" | grep -v "CONTAINER")
  fi
  if (( "$quiet" )); then
    for i in "${lines[@]}"; do
      echo "$i" | awk '{print $1}'
    done
  else
    echo "$header"
    for i in "${lines[@]}"; do
      echo "$i"
    done
  fi
}
copy_func _docker_ps_default _docker_ps
export -f _docker_ps

_docker_images_default() {
  local filter
  local quiet=0
  while (( "$#" )); do
    case "$1" in
      --quiet)
        quiet=1
        shift
        ;;
      --filter)
        filter="${2#reference=}"
        shift 2
        ;;
      *)
        shift
        ;;
    esac
  done

  local header
  local lines
  header=$(echo "$IMAGE_LIST" | head -n 1)
  if [[ -n "$filter" ]]; then
    mapfile -t lines < <(echo "$IMAGE_LIST" | grep -E "${filter%:*}" | grep -E "${filter#*:}")
  else
    mapfile -t lines < <(echo "$IMAGE_LIST" | grep -v "REPOSITORY")
  fi
  if (( "$quiet" )); then
    for i in "${lines[@]}"; do
      echo "$i" | awk '{print $3}'
    done
  else
    echo "$header"
    for i in "${lines[@]}"; do
      echo "$i"
    done
  fi
}
copy_func _docker_images_default _docker_images
export -f _docker_images

_docker_current_status=exited
export _docker_current_status
_docker_container() {
  echo "$_docker_current_status"
}
export -f _docker_container

_docker_image_default() {
  local id=$2

  echo "$IMAGE_LIST" | grep "$id" | awk '{printf "%s:%s\n", $1, $2}'
}
copy_func _docker_image_default _docker_image
export -f _docker_image

_docker_start_default() {
  echo "docker start" "$@"
  _docker_current_status=running
}
copy_func _docker_start_default _docker_start
export -f _docker_start

_docker_exec() {
  echo "docker exec" "$@"
}
export -f _docker_exec

_docker_run() {
  echo "docker run" "$@"
}
export -f _docker_run

_docker_stats_default() {
  return 0
}
copy_func _docker_stats_default _docker_stats
export -f _docker_stats

# test case: abort when docker is not running
_docker_stats_return_1() {
  return 1
}

copy_func _docker_stats_return_1 _docker_stats
$target || echo "successfully abort"
copy_func _docker_stats_default _docker_stats

# test case: abort when unrecognized distro is given
$target unknown_os || echo "successfully abort"

# test case: abort when non-existent container is given
$target --container unknown_container || echo "successfully abort"

# test case: abort when non-existent image is given
$target --image-name unknown_image || echo "successfully abort"

# test case: run a new container based on specified image when
# providing an option '--new'
$target --new xenial v1.7.0

# test case: run a new container without mounting volume
$target --new --mount false xenial v1.6.0

# test case: run a new container without mounting volume
$target --new --mount=false xenial v1.7.0

# test case: run a new container without mounting volume
$target --new --grasp-plugin /usr/src/graspPlugin  xenial v1.7.0

# test case: run a new container when no container is found based on
# specified image
CONTAINER_LIST_OLD="$CONTAINER_LIST"
CONTAINER_LIST=$(cat <<'EOF'
CONTAINER ID   IMAGE                         COMMAND                   CREATED          STATUS                      PORTS     NAMES
EOF
)
$target xenial v1.5.0
CONTAINER_LIST="$CONTAINER_LIST_OLD"

# test case: resume a running container
_docker_current_status=running
$target xenial v1.5.0

# test case: resume container when it is already exited
_docker_current_status=exited
$target xenial v1.5.0

# test case: abort when failing restarting container
_docker_start_cannot_start() {
  echo "docker start" "$@"
  # cannot start the container
  _docker_current_status=exited
}
copy_func _docker_start_cannot_start _docker_start
$target xenial v1.5.0 || echo "successfully abort"
copy_func _docker_start_default _docker_start

# test caee: typical usage
$target focal v1.7.0

echo "Complete!"
