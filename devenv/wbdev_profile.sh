if [ -z "$DEV_USER" ]; then
    export WORKSPACE_DIR="$HOME/wbdev"
else
    export WORKSPACE_DIR="$DEV_HOME/wbdev"
fi
export GOPATH="$WORKSPACE_DIR/go"
export PATH="/usr/local/go/bin:$GOPATH/bin:$PATH"
mkdir -p "$GOPATH"
if [ -n "$DEV_USER" ]; then
    chown "$DEV_USER.$DEV_USER" "$WORKSPACE_DIR" "$GOPATH"
fi
if [ -f /.devdir ]; then
    cd "$(cat /.devdir)"
fi
