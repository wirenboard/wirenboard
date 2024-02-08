DOCKER ?= docker
WBDEV_IMAGE ?= contactless/devenv

all:
	tar -czh . | $(DOCKER) build --no-cache -t $(WBDEV_IMAGE) -
	$(DOCKER) rm -f wbdevenv_tmp 2>/dev/null >/dev/null || true
	$(DOCKER) run -t --privileged --name wbdevenv_tmp $(WBDEV_IMAGE) bash -x /root/build.sh
	$(DOCKER) commit --change 'ENTRYPOINT ["/sbin/entrypoint.sh"]' wbdevenv_tmp $(WBDEV_IMAGE)
	$(DOCKER) rm -f wbdevenv_tmp

upentry:
	$(DOCKER) rm -f wbdevenv_tmp 2>/dev/null >/dev/null || true
	$(DOCKER) run --name wbdevenv_tmp --entrypoint /bin/bash $(WBDEV_IMAGE)
	$(DOCKER) cp entrypoint.sh wbdevenv_tmp:/sbin/entrypoint.sh
	$(DOCKER) cp wbdev_second_half.sh wbdevenv_tmp:/wbdev_second_half.sh
	$(DOCKER) cp projects.list wbdevenv_tmp:/projects.list
	$(DOCKER) cp build.sh wbdevenv_tmp:/root/build.shd
	$(DOCKER) cp wbdev_profile.sh wbdevenv_tmp:/etc/profile.d/
	$(DOCKER) commit --change 'ENTRYPOINT ["/sbin/entrypoint.sh"]' wbdevenv_tmp $(WBDEV_IMAGE)
	$(DOCKER) rm -f wbdevenv_tmp
