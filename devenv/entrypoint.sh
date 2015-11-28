#!/bin/bash
set -u -e

cmd=user
root=
shell_cmd=

if [ $# -gt 0 ]; then
    cmd="$1"
    shift
fi

case "$cmd" in
    user|chuser|root|chroot)
        if [[ $# -eq 0 ]]; then
            shell_cmd="/bin/bash -l"
        fi
        ;;
esac

DEV_UID="${DEV_UID:-1000}"
DEV_USER="${DEV_USER:-user}"
DEV_GID="${DEV_GID:-$DEV_UID}"
DEV_GROUP="${DEV_GROUP:-$DEV_USER}"
DEV_DIR="${DEV_DIR:-}"

rm -f /.devdir /rootfs/.devdir
if [ -n "$DEV_DIR" ]; then
    if [ -n "$shell_cmd" ]; then
        echo "$DEV_DIR" >/.devdir
        echo "$DEV_DIR" >/rootfs/.devdir
    elif ! cd "$DEV_DIR"; then
        echo "WARNING: can't chdir to $DEV_DIR"
    fi
fi

if ! getent group "$DEV_GROUP" >& /dev/null; then
    addgroup --gid "$DEV_GID" "$DEV_GROUP" >& /dev/null
fi

if ! getent passwd "$DEV_USER" >& /dev/null; then
    adduser --uid "$DEV_UID" --gecos "" --gid "$DEV_GID" --disabled-password --no-create-home "$DEV_USER" >& /dev/null
fi

# fix package installation issues
chown -R "$DEV_USER.$DEV_GROUP" /usr/local/go

chu () {
    # Note: here we use sudo because
    # 1 - current debian su doesn't support --session-command flag
    #     thus causing 'no job control' errors in subshell
    # 2 - su -c causes argument expansion problems with "$@"
    sudo -u "$DEV_USER" proot -R /rootfs -q qemu-arm-static $shell_cmd "$@"
}

case "$cmd" in
    user)
        if [ -n "$shell_cmd" ]; then
            su - "$DEV_USER"
        else
            su -p "$DEV_USER" -c "$@"
        fi
        ;;
    ndeb)
        su "$DEV_USER" -c "dpkg-buildpackage -us -uc"
        ;;
    gdeb)
        su "$DEV_USER" -c bash -c '. /etc/bash.bashrc; CC=arm-linux-gnueabi-gcc dpkg-buildpackage -b -aarmel -us -uc'
        ;;
    root)
        $shell_cmd "$@"
        ;;
    chuser)
        chu "$@"
        ;;
    make)
        chu make "$@"
        ;;
    cdeb)
        chu dpkg-buildpackage -us -uc
        ;;
    chroot)
        proot -R /rootfs -q qemu-arm-static -b "/home/$DEV_USER:/home/$DEV_USER" $shell_cmd "$@"
        ;;
    *)
        echo "Unknown command '$cmd'" 1>&2
        exit 1
esac
