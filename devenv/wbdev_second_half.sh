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

if [[ -z "$UID" ]]; then
    UID="$(id -u)"
fi

if [[ -z "$USER" ]]; then
    USER="$(id -n -u)"
fi

if [[ $OSTYPE == darwin* ]]
then
	VM_HOME="/home/$USER"
else
	VM_HOME=$HOME
fi

PREFIX="$VM_HOME/wbdev/go/src/github.com/contactless"
VOLUMES=""

if [[ -n "$DEV_VOLUME" ]]; then
    DEV_VOLUME_PREFIX="${DEV_VOLUME##*:}"

    case "$PWD" in
    "$DEV_VOLUME_PREFIX"*)
        ;;
    *)
        echo "DEV_VOLUME is set; PWD must start with $DEV_VOLUME_PREFIX"
        exit 1
        ;;
    esac

    VOLUMES="$VOLUMES -v $DEV_VOLUME"
    DEV_DIR="${PWD}"
elif [[ -z "$DEV_DIR" ]]; then
    DEV_DIR="$PREFIX/${PWD##*/}"
    VOLUMES="$VOLUMES -v $HOME:$VM_HOME -v ${PWD%/*}:$PREFIX"
fi


ENV_CMDLINE=""
for var in $(env | grep -o "WBDEV_[^=]*"); do
    ENV_CMDLINE="$ENV_CMDLINE -e $var"
done

docker run $DOCKER_TTY_OPTS --privileged --rm \
       -e DEV_UID=$UID \
       -e DEV_USER=$USER \
       -e DEV_DIR="$DEV_DIR" \
       -e DEV_TERM="$TERM" \
       $ENV_CMDLINE \
       -e DEB_BUILD_OPTIONS \
       -e DEB_BUILD_PROFILES \
       $VOLUMES \
       $ssh_opts \
       -h wbdevenv \
       $WBDEV_IMAGE \
       "$@"
