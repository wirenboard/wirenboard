# fw-toolchain

Docker image with the build environment for classic libwbmcu-based MCU
firmware (WB-MR, WB-MSW, WB-MAP, …, and the bootloader): one and the same
environment on developer machines and on CI.

The image is published to the internal registry as a multi-arch image
(linux/amd64 + linux/arm64):

```
registry.wirenboard.com/wirenboard/fw-toolchain:latest
```

The registry is internal: it is reachable from the office network / VPN
and requires `docker login registry.wirenboard.com` with your account.

## What is inside

All versions are pinned (see the Dockerfile):

| Tool | Version | Used for |
|------|---------|----------|
| Arm GNU Toolchain (arm-none-eabi) | 15.3.Rel1 (GCC 15.3.1) | firmware cross-compilation |
| gcc (host) | GCC 15.3.0 (gcc-15 from Debian forky) | unit tests (Unity) |
| python3 | 3.14.6-1 | libwbmcu-system build scripts |
| gcovr | 8.6 (upstream wheel, hash-locked in `gcovr-requirements.txt`) | `make coverage` |
| python3-pyelftools, python3-requests | pinned | ELF artifact analysis, scripting |
| make, git, s3cmd, curl, xz-utils | pinned | build and CI upload stages |

Reproducibility is fixed on three levels: the base image is pinned by
digest, apt sources point to snapshot.debian.org at a fixed date with
every installed package at an explicit version, and the cross-toolchain
tarball is pinned by release version and sha256 (both host
architectures). Rebuilding the image from the same Dockerfile yields
the same tool versions.

The cross-compiler version is pinned deliberately: firmware flash/RAM
limits are sensitive to it. Do not bump it casually.

The base is Debian forky (testing), chosen so that the host compiler is
the same GCC 15.3 branch as the cross-toolchain — unit tests and
firmware see identical compiler diagnostics.

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
    -v "$PWD":/w -w /w \
    registry.wirenboard.com/wirenboard/fw-toolchain:latest make
```

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

## Building the image yourself

If you have no registry access, the image builds locally from this
directory in a few minutes:

```
make -C fw-toolchain IMAGE=wirenboard/fw-toolchain:latest
```

## Updating the environment

Debian packages: bump the `SNAPSHOT` date and the package versions
together, in one PR — set the new date, drop the `=version` pins, build
the image, read the actually installed versions back with
`dpkg-query -W`, and write them into the Dockerfile as the new pins.

Cross-toolchain: bump `ARM_GNU_VERSION` and both `ARM_GNU_SHA256_*`
args (checksums are published next to the tarballs on
[gitlab.arm.com](https://gitlab.arm.com/tooling/gnu-toolchains-for-arm)).
A compiler bump must be verified against the flash/RAM limits of all
firmware repos before merging.

gcovr: bump versions in `gcovr-requirements.txt` and regenerate the
hashes (`pip download` for both architectures + `sha256sum`).

## Publishing (maintainers)

Until the `docker-image-build` Jenkins job learns to build this
directory (a `MAKE_DIR` parameter in jenkins-pipeline-lib is planned),
the multi-arch image is published manually:

```
docker buildx create --name multiarch --use   # once per machine
docker login registry.wirenboard.com
docker buildx build --platform linux/amd64,linux/arm64 \
    -t registry.wirenboard.com/wirenboard/fw-toolchain:latest \
    --push fw-toolchain/
```
