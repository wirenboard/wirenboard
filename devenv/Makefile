#имя образа
WBDEV_IMAGE ?= contactless/devenv-dev
#версия ОС
TARGET_VERSION = stretch


all:
#	tar -czh . | docker build --build-arg TARGET_VERSION=$(TARGET_VERSION) --no-cache -t $(WBDEV_IMAGE) -
#	docker rm -f $(WBDEV_IMAGE)_tmp 2>/dev/null >/dev/null || true
	docker build --build-arg TARGET_VERSION=$(TARGET_VERSION) --no-cache -t $(WBDEV_IMAGE)_tmp_0 .
	docker run -t --privileged --name dev_$(WBDEV_IMAGE)_tmp_0 $(WBDEV_IMAGE)_tmp_0 bash -x /root/build.sh
	docker commit  dev_$(WBDEV_IMAGE)_tmp_0 $(WBDEV_IMAGE)_tmp_1
#	docker rm -f dev_$(TARGET_VERSION)_tmp_0
#	docker run -t --privileged --name dev_$(WBDEV_IMAGE)_tmp_1 $(WBDEV_IMAGE)_tmp_1 bash -x /root/build2.sh
#	docker commit --change 'ENTRYPOINT ["/sbin/entrypoint.sh"]' dev_$(TARGET_VERSION)_tmp_1 $(WBDEV_IMAGE)
	docker commit dev_$(WBDEV_IMAGE)_tmp_0 $(WBDEV_IMAGE)
#	docker rm -f dev_$(TARGET_VERSION)_tmp_1

upentry:
	docker rm -f wbdevenv6_tmp 2>/dev/null >/dev/null || true
	docker run --name wbdevenv6_tmp --entrypoint /bin/bash $(WBDEV_IMAGE)
	docker cp entrypoint.sh wbdevenv6_tmp:/sbin/entrypoint.sh
	docker cp projects.list wbdevenv6_tmp:/projects.list
	docker cp wbdev_profile.sh wbdevenv6_tmp:/etc/profile.d/
	docker commit --change 'ENTRYPOINT ["/sbin/entrypoint.sh"]' wbdevenv6_tmp $(WBDEV_IMAGE)
	docker rm -f wbdevenv_tmp
clean:
	docker rm -f dev_$(WBDEV_IMAGE)_tmp_0 2>/dev/null >/dev/null || true
	docker rm -f dev_$(WBDEV_IMAGE)_tmp_1 2>/dev/null >/dev/null || true
	docker rm -f dev_$(WBDEV_IMAGE)_tmp_2 2>/dev/null >/dev/null || true
	docker image rm -f  $(WBDEV_IMAGE)_tmp_0 2>/dev/null >/dev/null || true
	docker image rm -f  $(WBDEV_IMAGE)_tmp_1 2>/dev/null >/dev/null || true
	docker image rm -f  $(WBDEV_IMAGE)_tmp_2 2>/dev/null >/dev/null || true

stage1:
	tar -czh . | docker build --build-arg TARGET_VERSION=$(TARGET_VERSION) --no-cache -t $(WBDEV_IMAGE)_tmp_0 -

stage2:
	docker run -t --privileged --name dev_$(WBDEV_IMAGE)_tmp_0 $(WBDEV_IMAGE)_tmp_0 bash -x /root/build.sh

stage3:
	docker commit  dev_$(WBDEV_IMAGE)_tmp_0 $(WBDEV_IMAGE)_tmp_1
	docker rm -f dev_$(WBDEV_IMAGE)_tmp_0