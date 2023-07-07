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

configure_container () {
  if (( $# != 1 )); then
    echo >&2 "usage: configure_container CONTAINER_ID"
    return 1
  fi
  container_id=$1

  if docker exec -i $container_id >&2 which python3; then
    :
  else
    docker exec -i $container_id >&2 apt-get -y update
    docker exec -i $container_id >&2 apt-get -y install python3-venv
  fi

  uid=$(id -u)
  docker exec -i $container_id id -un $uid 2>/dev/null && return

  gid=$(id -g)
  group=$(id -gn)
  docker exec -i $container_id groupadd -f -g $gid $group

  user=$(id -un)
  gecos=$(awk -F: "\$3 == $uid { print \$5 }" /etc/passwd)
  shell=$(awk -F: "\$3 == $uid { print \$7 }" /etc/passwd)
  docker exec -i $container_id \
	 useradd -u $uid -g $gid -c "$gecos" -d $HOME -s $shell $user

  docker exec -i $container_id bash -c "cp -a /etc/skel/.[^.]* $HOME"
  docker exec -i $container_id chown -R $user.$group $HOME
  echo $user
}

ensure_venv () {
  if (( $# != 3 )); then
    echo >&2 "usage: ensure_venv CONTAINER_ID CONTAINER_USER VENVDIR"
    return 1
  fi
  container_id=$1
  container_user=$2
  venvdir=$3
  [ -f $venvdir/bin/activate ] && return
  docker exec -i -u $container_user $container_id \
	 python3 -m venv $venvdir
  cat physics.py >> $venvdir/bin/re.py
}

workdir=$(cd . && pwd)/work
container_id=$(ensure_container $workdir)
container_user=$(configure_container $container_id)

venvdir=$workdir/venv
ensure_venv $container_id $container_user $venvdir
echo ok

#docker kill $(cat .physics.container)
#docker exec -ti --user $(id -u) $(cat .physics.container) bash
