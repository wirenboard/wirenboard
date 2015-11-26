all:
	tar -czh . | docker build -t contactless/devenv -
	docker rm -f wbdevenv_tmp || true
	docker run -t --privileged --name wbdevenv_tmp contactless/devenv bash -x /root/build.sh
	docker commit --change 'ENTRYPOINT ["/sbin/entrypoint.sh"]' wbdevenv_tmp contactless/devenv
	docker rm -f wbdevenv_tmp
