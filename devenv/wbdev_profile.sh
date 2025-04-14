if [ -z "$DEV_USER" ]; then
    export WORKSPACE_DIR="$HOME/wbdev"
else
    export WORKSPACE_DIR="/home/$DEV_USER/wbdev"
fi
mkdir -p "$WORKSPACE_DIR"
if [ -n "$DEV_USER" ]; then
    chown "$DEV_USER:$DEV_USER" "$WORKSPACE_DIR"
fi
if [ -f /.devdir ]; then
    cd "$(cat /.devdir)"
fi
