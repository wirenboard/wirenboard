# Сборка образа джобой или вручную: make -C fw-toolchain-legacy WBDEV_IMAGE=<тег>.
DOCKER ?= docker
WBDEV_IMAGE ?= wirenboard/fw-toolchain-legacy

# ARCH=amd64|arm64 — собрать под указанную архитектуру, а не под архитектуру
# машины. Обычный сборщик Docker молча игнорирует --platform, поэтому платформу
# задают базы: сюда подставляются digest'ы манифестов нужной архитектуры из тех
# же индексов, что стоят по умолчанию в ARG BASE и ARG FETCH_BASE. `make
# check-base` сверяет, что они взяты из этих индексов.
BASE_amd64 = debian@sha256:16ee3e11da473f6565ef94a715f1a38b3079e0664913be78869c336a71cb6085
BASE_arm64 = debian@sha256:3d3251ecfd190284f76c271e6c9dd19bb4d111f10bb9028ad8b8ac3d3b4914ea
FETCH_BASE_amd64 = debian@sha256:d8f17b92dc7ff10f9c1fdecab0ad21103d1d24aed823c3a0359e4f50adfab3eb
FETCH_BASE_arm64 = debian@sha256:5beecfe41dbb22033f1d7da3d51467cc20cdf8b63a309729ee959531f3baef1e

ARCH ?=
ifneq ($(ARCH),)
BASE := $(BASE_$(ARCH))
ifeq ($(BASE),)
$(error unknown ARCH=$(ARCH), add BASE_$(ARCH) and FETCH_BASE_$(ARCH) taken from the indexes in Dockerfile)
endif
BUILD_ARGS = --build-arg BASE=$(BASE) --build-arg FETCH_BASE=$(FETCH_BASE_$(ARCH))
# a stale digest would silently build the halves of one image from different
# bases, so an ARCH build is not allowed to start without the check
all: check-base
endif

.PHONY: all check-base

all:
	$(DOCKER) build $(BUILD_ARGS) -t $(WBDEV_IMAGE) .

check-base:
	@for var in BASE FETCH_BASE; do \
	    index=$$(sed -n "s/^ARG $$var=//p" Dockerfile); \
	    list=$$($(DOCKER) manifest inspect $$index); \
	    for arch in amd64 arm64; do \
	        case $$var-$$arch in \
	            BASE-amd64) digest=$(BASE_amd64);; \
	            BASE-arm64) digest=$(BASE_arm64);; \
	            FETCH_BASE-amd64) digest=$(FETCH_BASE_amd64);; \
	            FETCH_BASE-arm64) digest=$(FETCH_BASE_arm64);; \
	        esac; \
	        case "$$list" in \
	            *"$${digest#debian@}"*) echo "$${var}_$$arch ok";; \
	            *) echo "$${var}_$$arch is not in $$index"; exit 1;; \
	        esac; \
	    done; \
	done
