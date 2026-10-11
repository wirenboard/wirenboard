# Сборка образа джобой или вручную: make -C fw-toolchain-legacy WBDEV_IMAGE=<тег>.
# Образ строится поверх опубликованного fw-toolchain, поэтому собирать его
# после публикации fw-toolchain.
DOCKER ?= docker
WBDEV_IMAGE ?= wirenboard/fw-toolchain-legacy

# ARCH=amd64|arm64 — собрать под указанную архитектуру, а не под архитектуру
# машины. Обычный сборщик Docker молча игнорирует --platform, поэтому платформу
# задают базы: fw-toolchain — тегом половины, которую публикует джоба рядом с
# :latest, stretch — digest'ом манифеста из индекса в ARG GCC7_BASE. `make
# check-base` сверяет, что digest'ы stretch взяты из этого индекса.
BASE_amd64 = registry.wirenboard.com/wirenboard/fw-toolchain:latest-amd64
BASE_arm64 = registry.wirenboard.com/wirenboard/fw-toolchain:latest-arm64
GCC7_BASE_amd64 = debian@sha256:16ee3e11da473f6565ef94a715f1a38b3079e0664913be78869c336a71cb6085
GCC7_BASE_arm64 = debian@sha256:3d3251ecfd190284f76c271e6c9dd19bb4d111f10bb9028ad8b8ac3d3b4914ea

ARCH ?=
ifneq ($(ARCH),)
BASE := $(BASE_$(ARCH))
ifeq ($(BASE),)
$(error unknown ARCH=$(ARCH), add BASE_$(ARCH) and GCC7_BASE_$(ARCH))
endif
BUILD_ARGS = --build-arg BASE=$(BASE) --build-arg GCC7_BASE=$(GCC7_BASE_$(ARCH))
# a stale GCC7_BASE_* would silently build the halves of one image from
# different bases, so an ARCH build is not allowed to start without the check
all: check-base
endif

.PHONY: all check-base

all:
	$(DOCKER) build $(BUILD_ARGS) -t $(WBDEV_IMAGE) .

check-base:
	@index=$$(sed -n 's/^ARG GCC7_BASE=//p' Dockerfile); \
	list=$$($(DOCKER) manifest inspect $$index); \
	for pair in "amd64 $(GCC7_BASE_amd64)" "arm64 $(GCC7_BASE_arm64)"; do \
	    set -- $$pair; \
	    case "$$list" in \
	        *"$${2#debian@}"*) echo "GCC7_BASE_$$1 ok";; \
	        *) echo "GCC7_BASE_$$1 is not in $$index"; exit 1;; \
	    esac; \
	done
