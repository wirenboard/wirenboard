# Сборка образа джобой или вручную: make -C fw-toolchain WBDEV_IMAGE=<тег>.
# Имя переменной для образа прошивок неточное, зато джоба docker-image-build
# передаёт тег всем каталогам образов одинаково, без разбора кто есть кто.
DOCKER ?= docker
WBDEV_IMAGE ?= wirenboard/fw-toolchain

# ARCH=amd64|arm64 — собрать под указанную архитектуру, а не под архитектуру
# машины. Обычный сборщик Docker молча игнорирует --platform, поэтому платформу
# задаёт только база: сюда подставляется digest манифеста нужной архитектуры из
# того же индекса, что стоит по умолчанию в ARG BASE (и в ARG GCC7_BASE для
# этапа со старым компилятором). Строки ниже — цена этого пути: обновляя базу,
# править три digest'а вместо одного. `make check-base` сверяет, что они
# взяты из индексов Dockerfile'а.
# С buildx ни строк, ни сверки не нужно — там достаточно --platform.
BASE_amd64 = debian@sha256:d8f17b92dc7ff10f9c1fdecab0ad21103d1d24aed823c3a0359e4f50adfab3eb
BASE_arm64 = debian@sha256:5beecfe41dbb22033f1d7da3d51467cc20cdf8b63a309729ee959531f3baef1e
GCC7_BASE_amd64 = debian@sha256:16ee3e11da473f6565ef94a715f1a38b3079e0664913be78869c336a71cb6085
GCC7_BASE_arm64 = debian@sha256:3d3251ecfd190284f76c271e6c9dd19bb4d111f10bb9028ad8b8ac3d3b4914ea

ARCH ?=
ifneq ($(ARCH),)
BASE := $(BASE_$(ARCH))
ifeq ($(BASE),)
$(error unknown ARCH=$(ARCH), add BASE_$(ARCH) taken from the index in Dockerfile)
endif
BUILD_ARGS = --build-arg BASE=$(BASE) --build-arg GCC7_BASE=$(GCC7_BASE_$(ARCH))
# a stale BASE_* would silently build the halves of one image from different
# bases, so an ARCH build is not allowed to start without the check
all: check-base
endif

.PHONY: all check-base

all:
	$(DOCKER) build $(BUILD_ARGS) -t $(WBDEV_IMAGE) .

check-base:
	@for var in BASE GCC7_BASE; do \
	    index=$$(sed -n "s/^ARG $$var=//p" Dockerfile); \
	    list=$$($(DOCKER) manifest inspect $$index); \
	    for arch in amd64 arm64; do \
	        case $$var-$$arch in \
	            BASE-amd64) digest=$(BASE_amd64);; \
	            BASE-arm64) digest=$(BASE_arm64);; \
	            GCC7_BASE-amd64) digest=$(GCC7_BASE_amd64);; \
	            GCC7_BASE-arm64) digest=$(GCC7_BASE_arm64);; \
	        esac; \
	        case "$$list" in \
	            *"$${digest#debian@}"*) echo "$${var}_$$arch ok";; \
	            *) echo "$${var}_$$arch is not in $$index"; exit 1;; \
	        esac; \
	    done; \
	done
