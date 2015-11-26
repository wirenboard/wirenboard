#!/bin/bash
set -u -e

cmd=user
root=
shell_cmd=

if [ $# -gt 0 ]; then
    cmd="$1"
    shift
fi

if [ $# -eq 0 ]; then
    shell_cmd="/bin/bash -l"
fi

DEV_UID="${DEV_UID:-1000}"
DEV_USER="${DEV_USER:-user}"
DEV_GID="${DEV_GID:-$DEV_UID}"
DEV_GROUP="${DEV_GROUP:-$DEV_USER}"

if ! getent group "$DEV_GROUP" >& /dev/null; then
    addgroup --gid "$DEV_GID" "$DEV_GROUP" >& /dev/null
fi

if ! getent passwd "$DEV_USER" >& /dev/null; then
    adduser --uid "$DEV_UID" --gecos "" --gid "$DEV_GID" --disabled-password --no-create-home "$DEV_USER" >& /dev/null
fi

# fix package installation issues
chown -R "$DEV_USER.$DEV_GROUP" /usr/local/go

case "$cmd" in
    user)
        if [ -n "$shell_cmd" ]; then
            su - "$DEV_USER"
        else
            su "$DEV_USER" -c "$@"
        fi
        ;;
    root)
        $shell_cmd "$@"
        ;;
    chuser)
        # Note: here we use sudo because
        # 1 - current debian su doesn't support --session-command flag
        #     thus causing 'no job control' errors in subshell
        # 2 - su -c causes argument expansion problems with "$@"
        sudo -u "$DEV_USER" proot -R /rootfs -q qemu-arm-static $shell_cmd "$@"
        ;;
    chroot)
        proot -R /rootfs -q qemu-arm-static $shell_cmd "$@"
        ;;
    *)
        echo "Unknown command '$cmd'" 1>&2
        exit 1
esac
