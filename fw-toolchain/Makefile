# Тот же интерфейс, что у devenv/Makefile (переменная WBDEV_IMAGE),
# чтобы Jenkins-джоба docker-image-build могла собирать оба образа
# одним скриптом: make -C <каталог> WBDEV_IMAGE=<тег>.
DOCKER ?= docker
WBDEV_IMAGE ?= wirenboard/fw-toolchain

all:
	$(DOCKER) build -t $(WBDEV_IMAGE) .
