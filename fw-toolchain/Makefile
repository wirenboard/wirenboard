# Сборка образа джобой или вручную: make -C fw-toolchain IMAGE=<тег>.
DOCKER ?= docker
IMAGE ?= wirenboard/fw-toolchain

all:
	$(DOCKER) build -t $(IMAGE) .
