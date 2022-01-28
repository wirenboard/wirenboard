#!/bin/bash
# This file will be executed on host to run docker container

DOCKER_TTY_OPTS=-i
if [ -t 0 ]; then
    DOCKER_TTY_OPTS=-it
fi
ssh_opts=
if [ -n "$SSH_AUTH_SOCK" ]; then
    ssh_opts="-e SSH_AUTH_SOCK=/ssh-agent -v $SSH_AUTH_SOCK:/ssh-agent"
fi

ssh_port_forwarding=
if [ -n "$WBDEV_SSH_PORT_FORWARDING" ]; then
   ssh_port_forwarding="-p $WBDEV_SSH_PORT_FORWARDING:22"
fi

if [[ $OSTYPE == darwin* ]]
then
	VM_HOME="/home/$USER"
else
	VM_HOME=$HOME
fi

PREFIX="$VM_HOME/wbdev/go/src/github.com/contactless"

ENV_CMDLINE=""
for var in `env | grep -oP "WBDEV_[^=]*"`; do
    ENV_CMDLINE="$ENV_CMDLINE -e $var"
done

docker run $DOCKER_TTY_OPTS --privileged --rm \
       -e DEV_UID=$UID \
       -e DEV_USER=$USER \
       -e DEV_DIR="$PREFIX/${PWD##*/}" \
       -e DEV_TERM="$TERM" \
       $ENV_CMDLINE \
       -e DEB_BUILD_OPTIONS \
       -v $HOME:$VM_HOME \
       -v ${PWD%/*}:$PREFIX \
       $ssh_port_forwarding \
       $ssh_opts \
       -h wbdevenv \
       $WBDEV_IMAGE \
       "$@"
