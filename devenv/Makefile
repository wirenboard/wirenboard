#имя образа
WBDEV_IMAGE ?= contactless/devenv-6-stretch
#версия ОС
TARGET_VERSION = stretch


all:
        #Собираем "0" временный образ
	tar -czh . | docker build --no-cache -t $(WBDEV_IMAGE)_stage_0 -
#	docker rm -f wbdevenv_tmp 2>/dev/null >/dev/null || true
	#Запускаем контейнер "wbdevenv_tmp_stage_0" на  "0" временном образе и выполняем в нем 
	# создание rootfs для целевых архитектур. fakeroot не помогает. Именно --privileged
	# для монтирования /proc
	docker run -t --privileged --name wbdevenv_tmp_stage_0 $(WBDEV_IMAGE)_stage_0 bash -x /root/build.sh
#        
	docker commit --change 'ENTRYPOINT ["/sbin/entrypoint.sh"]' wbdevenv_tmp_stage_0 $(WBDEV_IMAGE)
#	docker rm -f wbdevenv_tmp_stage_0

upentry:
	docker rm -f wbdevenv_tmp 2>/dev/null >/dev/null || true
	docker run --name wbdevenv_tmp --entrypoint /bin/bash $(WBDEV_IMAGE)
	docker cp entrypoint.sh wbdevenv_tmp:/sbin/entrypoint.sh
	docker cp projects.list wbdevenv_tmp:/projects.list
	docker cp wbdev_profile.sh wbdevenv_tmp:/etc/profile.d/
	docker commit --change 'ENTRYPOINT ["/sbin/entrypoint.sh"]' wbdevenv_tmp $(WBDEV_IMAGE)
	docker rm -f wbdevenv_tmp

clean:
	docker rm -f wbdevenv_tmp_stage_0 2>/dev/null >/dev/null || true
	docker rm -f dev_$(TARGET_VERSION)_tmp_2 2>/dev/null >/dev/null || true
	docker image rm -f  $(WBDEV_IMAGE)_stage_0 2>/dev/null >/dev/null || true
	docker image rm -f  $(WBDEV_IMAGE)_tmp_1 2>/dev/null >/dev/null || true
	docker image rm -f  $(WBDEV_IMAGE)_tmp_2 2>/dev/null >/dev/null || true

test:
	docker commit --change 'ENTRYPOINT ["/sbin/entrypoint.sh"]' wbdevenv_tmp_stage_0 $(WBDEV_IMAGE)






