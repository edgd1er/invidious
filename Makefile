SHELL:=/bin/bash
DOCKER:=/usr/bin/docker
DOCKER_IMAGE_NAME:=edgd1er/invidious
PTF:=linux/amd64
DKRFILE:=./docker/Dockerfile
ARCHI:= $(shell dpkg --print-architecture)
IMAGE:=invidious
DUSER:=edgd1er
PROGRESS:=plain
WHERE:=--load
CACHE:=
aptCacher:=$(shell ifconfig wlp2s0 | awk '/inet /{print $$2}')
ALPINE:="3.23"
CRVERSION:=1.18.2
RELEASE:=1
STATIC:=0

default: build
all: lint build test

NO_DBG_SYMBOLS := 0

# Enable multi-threading.
# Warning: Experimental feature!!
# invidious is not stable when MT is enabled.
MT := 0
FLAGS ?=

# https://marmelab.com/blog/2016/02/29/auto-documented-makefile.html
help:
	@$(MAKE) -pRrq -f $(lastword $(MAKEFILE_LIST)) : 2>/dev/null | awk -v RS= -F: '/^# Fichiers/,/^# Base/ {if ($$1 !~ "^[#.]") {print $$1}}' | sort | egrep -v -e '^[^[:alnum:]]' -e '^$@$$'

lint:
	$(DOCKER) run --rm -i hadolint/hadolint < ./docker/Dockerfile
	$(DOCKER) run --rm -i hadolint/hadolint < ./docker/Dockerfile.arm64

build:
	$(DOCKER) buildx build $(WHERE) --platform $(PTF) -f $(DKRFILE) --build-arg ALPINE=$(ALPINE) --build-arg CRVERSION=$(CRVERSION) \
    $(CACHE) --progress=$(PROGRESS) --build-arg aptCacher=$(aptCacher) --build-arg release=$(RELEASE) -t ${DUSER}/$(IMAGE) .

build64:
	$(DOCKER) buildx build $(WHERE) --platform linux/arm64 -f $(DKRFILE).arm64 --build-arg ALPINE=$(ALPINE) --build-arg CRVERSION=$(CRVERSION) \
    $(CACHE) --progress=$(PROGRESS) --build-arg aptCacher=$(aptCacher) --build-arg release=$(RELEASE) -t ${DUSER}/$(IMAGE) .

push:
	$(DOCKER) login
	$(DOCKER) push $(DOCKER_IMAGE_NAME)

ifeq ($(STATIC), 1)
  FLAGS += --static
endif

ifeq ($(MT), 1)
  FLAGS += -Dpreview_mt
endif


ifeq ($(NO_DBG_SYMBOLS), 1)
  FLAGS += --no-debug
else
  FLAGS += --debug
endif

ifeq ($(API_ONLY), 1)
  FLAGS += -Dapi_only
endif


# -----------------------
#  Main
# -----------------------

all: invidious

get-libs:
	shards install --production

# TODO: add support for ARM64 via cross-compilation
invidious: get-libs
	crystal build src/invidious.cr $(FLAGS) --progress --stats --error-trace


run: invidious
	./invidious


# -----------------------
#  Development
# -----------------------


format:
	crystal tool format

test:
	crystal spec

verify:
	crystal build src/invidious.cr -Dskip_videojs_download \
	  --no-codegen --progress --stats --error-trace


# -----------------------
#  (Un)Install
# -----------------------

# TODO


# -----------------------
#  Cleaning
# -----------------------

clean:
	$(DOCKER) images -qf dangling=true | xargs --no-run-if-empty $(DOCKER) rmi
	$(DOCKER) volume ls -qf dangling=true | xargs --no-run-if-empty $(DOCKER) volume rm

distclean: clean
	rm -rf libs
	rm -rf ~/.cache/{crystal,shards}


# -----------------------
#  Help page
# -----------------------

help:
	@echo "Targets available in this Makefile:"
	@echo ""
	@echo "  get-libs         Fetch Crystal libraries"
	@echo "  invidious        Build Invidious"
	@echo "  run              Launch Invidious"
	@echo ""
	@echo "  format           Run the Crystal formatter"
	@echo "  test             Run tests"
	@echo "  verify           Just make sure that the code compiles, but without"
	@echo "                   generating any binaries. Useful to search for errors"
	@echo ""
	@echo "  clean            Remove build artifacts"
	@echo "  distclean        Remove build artifacts and libraries"
	@echo ""
	@echo ""
	@echo "Build options available for this Makefile:"
	@echo ""
	@echo "  RELEASE          Make a release build            (Default: 1)"
	@echo "  STATIC           Link libraries statically       (Default: 0)"
	@echo ""
	@echo "  API_ONLY         Build invidious without a GUI   (Default: 0)"
	@echo "  NO_DBG_SYMBOLS   Strip debug symbols             (Default: 0)"



# No targets generates an output named after themselves
.PHONY: all get-libs build amd64 run
.PHONY: format test verify clean distclean help
