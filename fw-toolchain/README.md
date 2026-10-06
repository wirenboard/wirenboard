# fw-toolchain

Docker image with the build environment for classic libwbmcu-based MCU
firmware (WB-MR, WB-MSW, WB-MAP, …, and the bootloader): one and the same
environment on developer machines and on CI.

The image is published to the internal registry (a multi-arch
linux/amd64 + linux/arm64 manifest is the goal; see *Publishing*):

```
registry.wirenboard.com/wirenboard/fw-toolchain:latest
```

The registry is reachable from the office network / VPN. The `wirenboard`
project in Harbor is public, so **pulling needs no `docker login`** — an
anonymous pull from inside the network just works. Credentials are only
needed to push, and pushing happens from a Jenkins runner (see *Publishing*).

## What is inside

All versions are pinned (see the Dockerfile):

| Tool | Version | Used for |
|------|---------|----------|
| gcc-arm-none-eabi | `15:14.2.rel1-1` — Arm GNU Toolchain 14.2.Rel1, GCC 14.2.1 | firmware cross-compilation |
| libnewlib-arm-none-eabi | 4.5.0 | cross libc (newlib, `nano.specs` / `rdimon.specs` / `nosys.specs`) |
| gcc (host) | GCC 14.2.0 (gcc-14 from Debian trixie) | unit tests (Unity) |
| python3 | 3.13.5-1 | libwbmcu-system build scripts |
| libc6-dev | 2.41-12+deb13u3 | host libc headers for the unit tests |
| gcovr | 7.2+really-1.1 | `make coverage` |
| python3-pyelftools, python3-requests | pinned | ELF artifact analysis, scripting |
| make, git, openssh-client, s3cmd, curl, 7zip | pinned | build and CI stages (submodule fetch over ssh, uploads, encryptor handoff packing) |
| nano, less, jq, xxd | pinned | convenience only, for a human in `fwdev bash` — the build never uses them |
| `/opt/gcov-flag/cc1` | built in the image from `gcc-arm-none-eabi-source` of the same version + `gcov-flag/` patches | on-device coverage builds only, see *Coverage on hardware* |

Everything is installed with `--no-install-recommends`, so the image holds
only what the Dockerfile names. Two packages that would otherwise arrive as
recommendations are therefore listed explicitly: `libc6-dev` (without it the
host gcc finds no `stdio.h` and the unit tests do not compile) and
`openssh-client` (firmware submodules use `git@github.com:` URLs).

Every tool comes from apt, `gcovr` included — the image has nothing from a
second source, so there is nothing to maintain besides the snapshot date. That
means gcovr `7.2+really-1.1` rather than upstream 8.x: every option
`build_common_coverage.mk` uses is present in 7.2, `make coverage` passes on it,
no repo sets `COVERAGE_FAIL_UNDER`, and the HTML report is the same. The one
thing 7.2 lacks is `--markdown`, which the HTML report makes redundant.

Everything, the cross-toolchain included, comes from apt — there are no
tarballs fetched from third-party hosts. The one binary built in the image,
the coverage `cc1`, is compiled from the apt source package
`gcc-arm-none-eabi-source`, so it follows the same rule. Reproducibility
is fixed on two levels: the base image is pinned by a dated tag plus sha256 digest
(Docker pulls by the digest; the tag is a human-readable name for the
same image), and apt sources point to snapshot.debian.org at a fixed
date with every installed package at an explicit version. Rebuilding
the image from the same Dockerfile yields the same tool versions.

The cross-compiler version is pinned deliberately: firmware flash/RAM
limits are sensitive to it. Do not bump it casually.

The base is Debian trixie (stable). Its host compiler (gcc-14, 14.2.0)
is the same GCC 14.2 branch as the cross-compiler (14.2.1), so unit
tests and firmware see identical compiler diagnostics.

## Docker setup

Linux: install Docker Engine following
[docs.docker.com/engine/install](https://docs.docker.com/engine/install/)
(on Debian/Ubuntu `apt-get install docker.io` also works), then add
yourself to the `docker` group and re-login:
`sudo usermod -aG docker $USER`. Under WSL2 either use Docker Desktop
for Windows or install the engine inside the WSL distro the same way.

macOS: install
[Docker Desktop](https://docs.docker.com/desktop/setup/install/mac-install/)
or [OrbStack](https://orbstack.dev/) (lighter). On Apple Silicon the
image runs natively (the arm64 variant is picked automatically) — no
emulation, no extra settings.

## Using the image locally

Pull once (office network / VPN):

```
docker pull registry.wirenboard.com/wirenboard/fw-toolchain:latest
```

Build all firmware models in a firmware repo checkout (clone with
`--recurse-submodules`):

```
cd wb-mr    # any classic libwbmcu firmware repo
docker run --rm -u "$(id -u):$(id -g)" -e HOME=/tmp \
    -e GIT_CONFIG_COUNT=1 \
    -e GIT_CONFIG_KEY_0=safe.directory -e GIT_CONFIG_VALUE_0="$PWD" \
    -v "$PWD":"$PWD" -w "$PWD" \
    registry.wirenboard.com/wirenboard/fw-toolchain:latest make
```

The checkout is mounted at the same path as on the host, so the paths
the build prints (e.g. the `file://` links of the coverage reports) are
valid on the host too.

The same way run any other make target: one model
(`make MODEL_MR6C_GD32E230K8`), unit tests (`make unittests`),
coverage (`make coverage`).

Build artifacts (`build/<MODEL>/<MODEL>.elf` / `.bin`) appear in the
checkout on the host as usual — point your debugger at the ELF directly,
nothing needs to be copied out of the container.

The bundled `fwdev` wrapper hides the boilerplate: a docker build
differs from a local one only by the `fwdev` prefix. Nothing is copied
anywhere — the checkout is bind-mounted into the container, artifacts
appear in place as usual. Standalone, like `wbdev` — can be downloaded
separately:

```
wget https://raw.githubusercontent.com/wirenboard/wirenboard/master/fw-toolchain/fwdev
chmod +x fwdev

cd wb-mr
fwdev make MODEL_MR6C_GD32E230K8   # instead of: make MODEL_MR6C_GD32E230K8
fwdev make unittests               # instead of: make unittests
fwdev bash                         # interactive shell in the environment
```

Notes:

* Nothing accumulates over time: `docker pull` downloads the image once
  and it stays in the local docker cache indefinitely, surviving
  reboots. `fwdev`/`docker run` never rebuild or re-download anything —
  they only start a disposable container from the cached image (~100 ms
  of overhead), which lives for the duration of one `make` and removes
  itself afterwards (`--rm`). The image changes only when you explicitly
  run `docker pull` again.
* Parallel work needs no setup: every `fwdev` invocation gets its own
  isolated container, so build firmware and run unit tests at the same
  time, in one checkout or several. Within a single checkout the usual
  make rules apply — the same as running two `make` commands side by
  side without docker.
* `-u "$(id -u):$(id -g)"` keeps build artifacts owned by you, not root.
* `GIT_CONFIG_*` marks the mounted checkout as a directory git may
  trust. Docker presents the bind-mount root itself as owned by root
  while everything inside it carries your uid; git checks the owner of
  the worktree root and otherwise refuses the repository ("detected
  dubious ownership in repository at `/w`"). Without it `$(shell git
  ...)` in a Makefile silently returns an empty string and artifact
  names and the firmware lose their branch and commit.
* On ARM machines (Apple Silicon and the like) docker picks the arm64
  variant of the image automatically — everything runs natively, without
  emulation. Firmware binaries built on amd64 and arm64 are identical.
* The image has no 32-bit host environment, so legacy unit tests that
  build with `gcc -m32` always fail on their first `-m32` compile: on
  amd64 with `bits/libc-header-start.h: No such file or directory`, on
  arm64 with `unrecognized command-line option '-m32'`. This is
  deliberate — `-m32` has no arm64 equivalent; migrate such tests
  instead of relying on it.
* For library development in the project layout (a library's unit tests
  reference sibling repos), mount the workspace root instead of the
  library checkout and set `-w` to the library directory.

## Coverage on hardware (gcov flag mode)

Coverage of firmware by the hardware tests is measured on the
device itself with the patched GCC from
[wirenboard/gcov-embedded](https://github.com/wirenboard/gcov-embedded):
instead of 64-bit gcov counters every CFG edge gets a one-byte "taken" flag
(a single `strb`), so the flags fit in MCU RAM and are read off the running
device over Modbus. The image carries that compiler as one extra file,
`/opt/gcov-flag/cc1`:

* it is built in the `gcov-flag-cc1` stage of the Dockerfile from
  `gcc-arm-none-eabi-source` — the source of exactly the installed
  `gcc-arm-none-eabi` (one `ARM_GCC_VERSION` pins both), configured with the
  flags of its `debian/rules` — plus the three patches in `gcov-flag/`, taken
  from gcov-embedded `66e6131`;
* the patches are gated at run time by the environment variable
  `GCOV_FLAG_MODE`: without it the patched `cc1` emits the same code as the
  stock one;
* the stock `cc1` is not replaced. The patched one is used only on request,
  through `-B` of the stock driver, so headers, multilibs, newlib and the
  linker stay the stock ones:

```
GCOV_FLAG_MODE=1 arm-none-eabi-gcc -B/opt/gcov-flag/ --coverage -DCOVERAGE ...
```

Objects it compiles say `(15:14.2.rel1-1+gcov-flag)` in `.comment`, so a
coverage build is recognisable by its ELF.

The image build checks the compiler: a probe compiled by the patched `cc1`
without `GCOV_FLAG_MODE` must give the same assembly as the stock one, with
and without `--coverage`, and with `GCOV_FLAG_MODE=1` the counters must be
byte flags. A mismatch fails the build.

The firmware side (the flag region exposed as Modbus registers) and the host
tools that turn a flag dump into an lcov report live in gcov-embedded and
`libwbmcu-system`.

## Building the image yourself

If you have no registry access, the image builds locally from this
directory in a few minutes (most of it is compiling the coverage `cc1`,
about 3.5 min natively on 8 cores):

```
make -C fw-toolchain WBDEV_IMAGE=wirenboard/fw-toolchain:latest
```

To build for the other architecture, add `ARCH=amd64` or `ARCH=arm64`.
That needs qemu binfmt registered on the host (`docker run --privileged
--rm tonistiigi/binfmt --install arm64`), and it is slow — emulated apt
takes minutes, not seconds, and compiling the coverage `cc1` under
emulation takes many times longer than natively. Note that `docker build --platform` does
**not** do this: the legacy builder ignores the flag without a word, so
the Makefile selects the platform through the base image digest instead.

## Updating the environment

Base image: pick a fresh dated tag of `debian:trixie` on Docker Hub,
read its manifest digest
(`docker manifest inspect debian:trixie-YYYYMMDD`), and update the tag
and the digest in `ARG BASE` together. That digest is the **index**, out
of which docker takes the right architecture on its own. `ARCH=` builds
need the digest of a single architecture instead, so the same index is
also spelled out per architecture in the Makefile (`BASE_amd64`,
`BASE_arm64`) — update those two at the same time. `make check-base`
verifies both are members of the index pinned in the Dockerfile, and an
`ARCH=` build runs it first: a stale one would silently build the halves
of a single image from two different bases. With buildx none of this
would exist — one `--platform` flag replaces the three digests and the
check.

Debian packages: bump the `SNAPSHOT` date and the package versions
together, in one PR — set the new date, drop the `=version` pins, build
the image, read the actually installed versions back with
`dpkg-query -W`, and write them into the Dockerfile as the new pins.

Cross-toolchain: it is an apt package like the rest, so it moves with
the snapshot date — bump `ARM_GCC_VERSION` (it pins `gcc-arm-none-eabi`
and the source of the coverage `cc1` together) and
`libnewlib-arm-none-eabi` the same way. If the `gcov-flag/` patches no
longer apply to the new source, or the coverage self-test fails, the image
build stops: update the patches together with the compiler.
`binutils-arm-none-eabi` is left unpinned on purpose: its binNMU revision
differs per architecture (`+b1` on amd64, `+b2` on arm64 at the current
snapshot), and a single `pkg=version` has to satisfy both halves of a
multi-arch build; the snapshot date still determines it unambiguously.
`gawk` in the coverage `cc1` stage is left unpinned for the same reason. A compiler bump must
be verified against the flash/RAM limits of all firmware repos before
merging.

gcovr: an apt package like the rest — it moves with the snapshot date.

## Publishing (maintainers)

The image is published **only from a Jenkins runner** — the registry push
credentials (`registry-wirenboard-robot-push-account`) live there, not on
developer machines. There is no supported way to push this image by hand.

The job is
[`docker-image-build`](https://jenkins.wirenboard.com/job/docker-image-build/)
(`docker/buildImage.groovy` in jenkins-pipeline-lib). It checks out this repo
on the `devenv-image-builder` node, runs `make` in the `MAKE_DIR` directory
once per architecture of `ARCHES` (`ARCH=amd64`, then `ARCH=arm64`), pushes
each half as `<tag>-<arch>` and joins them into one multi-arch manifest under
`<tag>`.

To publish, after the PR is merged run it with «Build with Parameters»:

```
MAKE_DIR    fw-toolchain
IMAGE_TAG   wirenboard/fw-toolchain:latest
ARCHES      amd64_arm64
```

The rest stays at the defaults: `GIT_BRANCH` = `master`,
`INTERNAL_REGISTRY` = `registry.wirenboard.com`, `PULL_IMAGES` on — the job
also pulls the new image onto the build nodes. Then check that both halves
are there:

```
docker manifest inspect registry.wirenboard.com/wirenboard/fw-toolchain:latest
```

lists `linux/amd64` and `linux/arm64`. `:latest` is the only tag, so every
`docker pull` gets the new environment — tell the team. The registry drops a
superseded image after about a day; to stay on the previous environment,
build it locally from its commit.

A trial run before merging is the same job with `GIT_BRANCH` set to the PR
branch, a test `IMAGE_TAG` that nothing uses (e.g.
`wirenboard/fw-toolchain_test:latest`) and `PULL_IMAGES` off: `:latest` and
the build nodes stay untouched.

Multi-arch has no first-class support on the node. There is no buildx — the
build log carries Docker's legacy-builder notice, *"Install the buildx
component to build images with BuildKit"* — and Jenkins has no arm64 agent at
all, so the arm64 half is built under qemu emulation (the binfmt is installed
on the node by the `wb_buildagent` role) and is the slower one. A single
`docker-buildx-plugin` package would replace the per-architecture builds and
the manifest step with one `--platform` flag; that is an infra decision.
