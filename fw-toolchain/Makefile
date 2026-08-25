# Сборка образа джобой или вручную: make -C fw-toolchain IMAGE=<тег>.
DOCKER ?= docker
IMAGE ?= wirenboard/fw-toolchain

# ARCH=amd64|arm64 — собрать под указанную архитектуру, а не под архитектуру
# машины. Обычный сборщик Docker молча игнорирует --platform, поэтому платформу
# задаёт только база: сюда подставляется digest манифеста нужной архитектуры из
# того же индекса, что стоит по умолчанию в ARG BASE. Две строки ниже — цена
# этого пути: обновляя базу, править три digest'а вместо одного. `make
# check-base` сверяет, что эти два взяты из индекса Dockerfile'а.
# С buildx ни строк, ни сверки не нужно — там достаточно --platform.
BASE_amd64 = debian@sha256:d8f17b92dc7ff10f9c1fdecab0ad21103d1d24aed823c3a0359e4f50adfab3eb
BASE_arm64 = debian@sha256:5beecfe41dbb22033f1d7da3d51467cc20cdf8b63a309729ee959531f3baef1e

ARCH ?=
ifneq ($(ARCH),)
BASE := $(BASE_$(ARCH))
ifeq ($(BASE),)
$(error unknown ARCH=$(ARCH), add BASE_$(ARCH) taken from the index in Dockerfile)
endif
BUILD_ARGS = --build-arg BASE=$(BASE)
# a stale BASE_* would silently build the halves of one image from different
# bases, so an ARCH build is not allowed to start without the check
all: check-base
endif

.PHONY: all check-base

all:
	$(DOCKER) build $(BUILD_ARGS) -t $(IMAGE) .

check-base:
	@index=$$(sed -n 's/^ARG BASE=//p' Dockerfile); \
	list=$$($(DOCKER) manifest inspect $$index); \
	for pair in "amd64 $(BASE_amd64)" "arm64 $(BASE_arm64)"; do \
	    set -- $$pair; \
	    case "$$list" in \
	        *"$${2#debian@}"*) echo "BASE_$$1 ok";; \
	        *) echo "BASE_$$1 is not in $$index"; exit 1;; \
	    esac; \
	done
