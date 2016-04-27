#!/bin/bash
docker rm -f wbdevenv_tmp 2>/dev/null >/dev/null || true
if docker run -it --name wbdevenv_tmp --entrypoint /bin/bash contactless/devenv "$@"; then
    docker commit --change 'ENTRYPOINT ["/sbin/entrypoint.sh"]' wbdevenv_tmp contactless/devenv
fi
docker rm -f wbdevenv_tmp
