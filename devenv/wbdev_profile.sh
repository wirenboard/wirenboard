if [ -z "$DEV_USER" ]; then
    export GOPATH="$HOME/go"
else
    export GOPATH="/home/$DEV_USER/go"
fi
export PATH="/usr/local/go/bin:$PATH"
mkdir -p "$GOPATH"
if [ -f /.devdir ]; then
    cd "$(cat /.devdir)"
fi
