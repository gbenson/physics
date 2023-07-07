#!/bin/bash

set -eu
set -x

start_container_args='WORKDIR [CONTAINER_IMAGE]'
start_container () {
  if (( $# < 1 || $# > 2 )); then
    echo >&2 "usage: start_container $start_container_args"
    return 1
  fi
  workdir=$1
  if (( $# > 2 )); then
    image=$2
  else
    [ -f /etc/lsb-release ] && source /etc/lsb-release
    image=$(echo $DISTRIB_ID | tr '[:upper:]' '[:lower:]'):$DISTRIB_RELEASE
  fi
  [ -d $workdir ] || mkdir -p $workdir
  docker run -d --rm --mount type=bind,src=$workdir,target=$workdir $image sleep 365d
}

ensure_container () {
  container_id_file=$(pwd)/.physics.container
  if [ -f $container_id_file ]; then
    container_id=$(cat $container_id_file)
    if docker ps -q --no-trunc | grep -q $container_id; then
      echo $container_id
      return
    else
      unset container_id
      rm -f $container_id_file
    fi
  fi
  container_id=$(start_container "$@")
  echo $container_id | tee $container_id_file
}

workdir=$(cd . && pwd)/work
container_id=$(ensure_container $workdir)
echo ok
