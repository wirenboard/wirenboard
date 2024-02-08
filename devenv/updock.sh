#!/bin/bash

DOCKER=${DOCKER:-"docker"}

$DOCKER rm -f wbdevenv_tmp 2>/dev/null >/dev/null || true
if $DOCKER run -it --name wbdevenv_tmp --entrypoint /bin/bash contactless/devenv "$@"; then
    $DOCKER commit --change 'ENTRYPOINT ["/sbin/entrypoint.sh"]' wbdevenv_tmp contactless/devenv
fi
$DOCKER rm -f wbdevenv_tmp
