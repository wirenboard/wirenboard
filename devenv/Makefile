all:
	tar -czh . | docker build -t contactless/devenv -
	docker rm -f wbdevenv_tmp 2>/dev/null >/dev/null || true
	docker run -t --privileged --name wbdevenv_tmp contactless/devenv bash -x /root/build.sh
	docker commit --change 'ENTRYPOINT ["/sbin/entrypoint.sh"]' wbdevenv_tmp contactless/devenv
	docker rm -f wbdevenv_tmp

upentry:
	docker rm -f wbdevenv_tmp 2>/dev/null >/dev/null || true
	docker run --name wbdevenv_tmp --entrypoint /bin/bash contactless/devenv
	docker cp entrypoint.sh wbdevenv_tmp:/sbin/entrypoint.sh
	docker cp projects.list wbdevenv_tmp:/projects.list
	docker cp wbdev_profile.sh wbdevenv_tmp:/etc/profile.d/
	docker commit --change 'ENTRYPOINT ["/sbin/entrypoint.sh"]' wbdevenv_tmp contactless/devenv
	docker rm -f wbdevenv_tmp
