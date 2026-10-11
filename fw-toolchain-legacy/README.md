# fw-toolchain-legacy

Firmware build environment of the previous build machine, as close to it as
a container gets:

| | |
|---|---|
| OS | Debian 9 stretch |
| `arm-none-eabi-gcc` | 7.3.1 20180622 (Arm 7-2018-q2-update), binutils 2.30, newlib 3.0.0 |
| make | 4.1 |
| python3 | 3.5.3 |
| git | 2.11.0 |
| host gcc (unit tests) | 6.3.0 |
| directory order | that of the old machine's ext4 (see below) |

```
registry.wirenboard.com/wirenboard/fw-toolchain-legacy:latest
```

Use it to build a firmware or the bootloader the way the old machine does,
or to compare a build between the old and the new environment. Regular
builds stay on `fw-toolchain`. The image does not depend on `fw-toolchain`
and does not carry its CI tools (s3cmd, 7zip, …): it is for building.

## Usage

`fwdev-legacy` is `fwdev` with this image:

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

`FWDEV_IMAGE` still overrides the image, e.g. to pin a digest. Nothing has
to be passed to make: the compiler in `/opt/gcc-arm-none-eabi-7` (the same
path as on the old machine) is first on `PATH`.

## The compiler

Built the same way the old machine got it: Arm's source package
7-2018-q2-update compiled by Arm's own `install-sources.sh` /
`build-prerequisites.sh` / `build-toolchain.sh` on stretch, skipping only
the Windows build, the manuals and gdb with python. This runs in a
Dockerfile stage on each architecture, so amd64 and arm64 get the same
compiler; Arm never released a prebuilt aarch64 one. The version string is
pinned to the old machine's, `7-2018-q4-major` (the script derives it from
the build date).

The source tarballs `install-sources.sh` would fetch itself are downloaded
beforehand in a separate trixie stage (stretch's CA bundle is too old for
today's https) and checked by sha256 — several of its URLs are dead. libelf
0.8.13 no longer has a live upstream and comes from the Internet Archive
copy of its original site.

The Debian package of the same GCC (`gcc-arm-none-eabi 15:7-2018-q2-6` in
buster) is not a substitute: it compiles to the same object code, but ships
binutils 2.31 and newlib 3.1, so the linked `.bin` differs.

## Directory order

The same compiler alone does not give the old machine's binary: the layout
also depends on the order the object files are linked in, and make 4.1
takes it from `$(wildcard ...)` in the order `readdir` returns. On the old
machine that is the order of its ext4 with directory indexing: by a hash of
the file name (half_md4 seeded with the filesystem's own seed), and for a
directory that fits into one block "." and ".." are hashed like any name.
That order is a property of that disk, not of the make version.

`make` in this image is a wrapper that preloads `ext4_dir_order.so`, which
returns directory entries in that order, computed from the old machine's
parameters:

* `EXT4_DIR_HASH_SEED` — "Directory Hash Seed" of the filesystem the old
  machine builds on, baked in at image build time (`LAPTOP_DIR_HASH_SEED`);
* `EXT4_DIR_BLOCK_SIZE` — its block size (4096);
* `EXT4_DIR_CSUM` — 1 if it has `metadata_csum`.

All three come from `dumpe2fs -h` of that filesystem. Without a seed the
wrapper changes nothing and make 4.1 uses the order of the disk the
checkout lives on. The programs make runs see the same order, as they did
on the old machine.

## Building and publishing

The job `docker-image-build` builds it like any other image directory:

```
make -C fw-toolchain-legacy WBDEV_IMAGE=wirenboard/fw-toolchain-legacy:latest
```

The compiler stage takes about two hours on amd64 and several times longer
on arm64 under qemu.

`ARCH=amd64|arm64` selects the architecture through the base image digests
in the Makefile (stretch, and trixie for the download stage); `make
check-base` verifies them against the indexes in the Dockerfile.
