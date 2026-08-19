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
| gcc (host), gcc-multilib on amd64 | GCC 15.3.0 (gcc-15 from Debian forky) | unit tests (Unity) |
| python3 | 3.13.5-1 | libwbmcu-system build scripts |
| qemu-system-arm | 1:10.0.11+ds | layout-sensitive tests on an emulated Cortex-M |
| gcovr | 7.2+really-1.1 | `make coverage` |
| make, git, s3cmd, curl | pinned | build and CI upload stages |

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
firmware see identical compiler diagnostics. The long-term goal is one
compiler for everything: tests migrate to libwbmcu-system's
`RUN_ON_QEMU` mode (built by the very same `arm-none-eabi-gcc`, run on
`qemu-system-arm`), after which host gcc and gcc-multilib leave the
image entirely.

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

A convenient alias:

```
alias fwmake='docker run --rm -u "$(id -u):$(id -g)" -e HOME=/tmp -v "$PWD":/w -w /w registry.wirenboard.com/wirenboard/fw-toolchain:latest make'
```

Notes:

* `-u "$(id -u):$(id -g)"` keeps build artifacts owned by you, not root.
* On ARM machines (Apple Silicon and the like) docker picks the arm64
  variant of the image automatically — everything runs natively, without
  emulation. Firmware binaries built on amd64 and arm64 are identical.
* Unit tests that build with `gcc -m32` work on amd64 only
  (`gcc-multilib` does not exist on arm64). libwbmcu-system's
  `RUN_ON_QEMU` mode is the arch-independent replacement: it runs
  layout-sensitive tests on `qemu-system-arm`, available in this image
  on both architectures.
* For library development in the project layout (a library's unit tests
  reference sibling repos), mount the workspace root instead of the
  library checkout and set `-w` to the library directory.

## Building the image yourself

If you have no registry access, the image builds locally from this
directory in a few minutes:

```
make -C fw-toolchain WBDEV_IMAGE=wirenboard/fw-toolchain:latest
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
