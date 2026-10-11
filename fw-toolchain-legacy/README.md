# fw-toolchain-legacy

`fw-toolchain` plus the compiler of the previous firmware build machine,
first on `PATH`: Arm GNU Toolchain 7-2018-q2-update — GCC 7.3.1 20180622,
binutils 2.30, newlib 3.0.0. Everything else (make, python, git, host gcc
for unit tests, …) is `fw-toolchain` as is.

```
registry.wirenboard.com/wirenboard/fw-toolchain-legacy:latest
```

Use it to build a firmware or the bootloader the way the old machine did,
or to compare a build between the two compilers. Regular builds stay on
`fw-toolchain`.

## Usage

The same as `fw-toolchain`, only the image differs. `fwdev-legacy` is
`fwdev` with this image:

```
fwdev-legacy make MODEL_MR6C_GD32E230K8
```

It runs the `fwdev` lying next to it, in the sibling `fw-toolchain/`
directory (the repository layout) or on `PATH`, so install both:

```
wget https://raw.githubusercontent.com/wirenboard/wirenboard/master/fw-toolchain/fwdev
wget https://raw.githubusercontent.com/wirenboard/wirenboard/master/fw-toolchain-legacy/fwdev-legacy
chmod +x fwdev fwdev-legacy
```

`FWDEV_IMAGE` still overrides the image, e.g. to pin a digest.

On CI: `buildFirmware(image: 'registry.wirenboard.com/wirenboard/fw-toolchain-legacy:latest')`.

`arm-none-eabi-gcc` in this image is 7.3.1; nothing has to be passed to
make. The compiler lives in `/opt/gcc-arm-none-eabi-7`, the same path as
on the old machine.

## How the compiler is built

The same way the old machine got it: Arm's source package
7-2018-q2-update compiled by Arm's own `install-sources.sh` /
`build-prerequisites.sh` / `build-toolchain.sh` on Debian stretch, the OS
of that machine, skipping only the Windows build, the manuals and gdb with
python. This runs in a Dockerfile stage on each architecture, so amd64 and
arm64 get the same compiler; Arm never released a prebuilt aarch64 one.
The version string is pinned to the old machine's, `7-2018-q4-major` (the
script derives it from the build date).

The source tarballs `install-sources.sh` would fetch itself are downloaded
beforehand and checked by sha256 — several of its URLs are dead. libelf
0.8.13 no longer has a live upstream and comes from the Internet Archive
copy of its original site.

The stage takes about two hours on amd64 and several times longer on
arm64 under qemu, so the image is rebuilt only when needed: after a
`fw-toolchain` update that should reach it, or a change here.

The Debian package of the same GCC (`gcc-arm-none-eabi 15:7-2018-q2-6` in
buster) is not a substitute: it compiles to the same object code, but ships
binutils 2.31 and newlib 3.1, so the linked `.bin` differs from the old
machine's.

## Reproducing a binary of the old machine

The compiler alone gives a byte-identical binary only if the object files
are linked in the same order. make 4.1 on the old machine returns
`$(wildcard src/*.c)` in the directory order of its disk, while make 4.4
here sorts it, and the layout shifts by a few bytes. That order is a
property of the old machine's filesystem, not of the make version, so it
can only be taken from the link line of the old build log and passed as
`OBJECTS=...`.

## Building and publishing

Built on top of the published `fw-toolchain`, so publish that first. The
job `docker-image-build` builds it like any other image directory:

```
make -C fw-toolchain-legacy WBDEV_IMAGE=wirenboard/fw-toolchain-legacy:latest
```

`ARCH=amd64|arm64` selects the architecture through the bases: the
`latest-<arch>` half of `fw-toolchain` the job publishes next to `:latest`,
and the stretch manifest digest from the Makefile. `make check-base`
verifies the stretch digests against the index in the Dockerfile.
