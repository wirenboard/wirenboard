wirenboard
==========

WirenBoard-specific software packages, tools and default configs to make rootfs, hardware stuff, development environment and so on.

Check out http://www.contactless.ru/wirenboard for details about Wiren Board

Development Environment
=======================

Bundled `wbdev` script launches docker-based WirenBoard
development environment. It can be used as standalone script
and can be downloaded separately:

```
wget https://raw.githubusercontent.com/wirenboard/wirenboard/master/wbdev
chmod +x wbdev
```

In order to use the script, you must
[install docker](http://docs.docker.com/engine/installation/ubuntulinux/)
first.

The development environment consists "host" environment which is
Debian "stretch" Linux image used to build Python noarch packages,
Go-based packages such as `wb-rules` and `wb-mqtt-confed` and
`wb-mqtt-homeui` frontend.

Cross-compilation is used to build C/C++ packages such as `wb-mqtt-serial`
for armhf and armel target architectures. It's implemented using
[Debian sbuild](https://wiki.debian.org/sbuild) with different 
non-virtualized chroot rootfses for each Debian release.

It also contains ARM qemu virtualized chroot environments with root
filesystems closely resembling those on Wiren Board controllers.
These chroot environments are used to build C/C++-based
packages in 'chroot' compatibility mode.

When `wbdev` script is invoked, a user with the same user
name, UID and GID as current user is created inside the container.
The user's home directory is mounted inside the container under the
same path as its path on the host machine, i.e. all paths to files
under the user's home directory on the host machine are also valid
inside the container.

The script starts the container using `--rm` flag, which means that
the container is removed on exit and any changes made to the
development environment *itself* are lost. If you want to modify the
development image you should start the container by hand without
`--rm` flag and then use `docker commit` to commit your changes to the
image, or, preferably, alter Dockerfile and/or scripts used to build
the image in `devenv/` subdirectory of this project and then invoke
`make` there to rebuild the image (note though that it may take 90
minutes or more to rebuild it).

*NOTE:* the script works only when the OS on the user's machine
follows the
[User Private Groups](https://wiki.debian.org/UserPrivateGroups)
concept (used by modern Ubuntu and Debian versions among others). Most
importantly it requires user's primary GID to be equal to user's
UID. Also, you should not start `wbdev` script as root because
it will not work properly in this case.

The script accepts four shell invocation commands: `user` (the
default), `root`, `chuser` and `chroot`. If any arguments are present
after such command, they're interpreted as a command that will be
executed in corresponding environment. In addition to shell invocation
commands there are `ndeb`, `gdeb`, `cdeb` and `make` commands that can
be used to build projects without starting a session inside the
container.

Inside the Docker container there are ARM qemu virtualized chroots
with root filesystems closely resembling those on Wiren Board controllers.

Usage:

* `wbdev user [command...]` or just `wbdev` starts the
  container in host user mode. Use it to work on noarch, Go and Web
  UI projects.
* `wbdev chuser [command...]` starts the container in ARM qemu
  chroot user mode.  Use it to work on C++ projects and other packages
  that need to be built in ARM qemu chroot environment.
* `wbdev root [command...]` is used to start the container in
  root mode. Use it if you need to try out some temporary changes to
  the development environment.
* `wbdev chroot [command...]` is used to start the container in ARM
  qemu chroot mode. Use it if you need to try out some temporary
  changes to the chroot environment, e.g. try to install a package
  built for Wiren Board.
* `wbdev ndeb` builds a noarch deb from a project in the current
  directory.
* `wbdev gdeb` builds an armel or armhf (see below) deb from a Go project in the current
  directory (should be used under a wbdev workspace, see **WBDEV
  Workspace** below).
* `wbdev cdeb [args...]` builds an armel or armhf deb from a C++ project in the current
  directory. Sbuild is used by default. Arguments are passed to sbuild.
  For instance, ` --build-failed-commands="%SBUILD_SHELL"` will invoke shell in sbuild env
  if build is failed. See
  [man sbuild](https://manpages.debian.org/stretch/sbuild/sbuild.1.en.html) for details.
* `wbdev make [args...]` invokes `make` in qemu chroot environment in
  the current directory.
* `wbdev hmake [args...]` invokes `make` in host user mode in the
  current directory. Use it to build x86_64 binaries and to do `wbdev hmake test`
  on C++ projects.
* `wbdev update-workspace` creates or updates wbdev workspace in
  `~/wbdev` (see **WBDEV Workspace** below).

To change target architecture you should use environment variable
WBDEV_TARGET. Possible values:

* `wb5` build package for armel target (latest WB5.x)
* `wb6` build package for armhf target (WB6.x) 

Debian release (default `stretch`) could be overriden by `WBDEV_RELEASE` environment
variable.

Set `WBDEV_BUILD_METHOD=qemuchroot` to use legacy qemu virtualized builds.

Set nonzero value to `WBDEV_USE_EXPERIMENTAL_DEPS` or `WBDEV_USE_UNSTABLE_DEPS` to
add experimental or unstable Wiren Board Debian repositories respectively.

If required, another Docker image could be set via
environment variable WBDEV_IMAGE.

You may need to make changes to your shell init files such as
`~/.bashrc` to avoid confusion between host machine and development
environment command prompts. For `bash`, you may add the following to
the end of your `~/.bashrc`:

```
if [ "$HOSTTYPE" = "arm" ]; then
   PS1="(wbch)$PS1"
elif [ "$HOSTNAME" = "wbdevenv" ]; then
   PS1="(wbdev)$PS1"
fi
```

This will prefix the command prompt with `(wbch)` in case when the
chroot user mode and with `(wbdev)` in case when the host user mode.

WBDEV Workspace
===============

Go-based Wiren Board apps make use of [glide](https://glide.sh/)
package manager which requires proper Go workspace to function.
To make this part easier and for added convenience for other WB
projects `wbdev update-workspace` builds and unified directory
layout for WB projects, performing `git clone` for projects
listed in [devenv/projects.list](devenv/projects.list):

```
~/wbdev
   |
   +--- homeui
   |
   +--- wb-mqtt-serial
   |
   +--- other non-Go apps...
   |
   +--- go/
         +- src/
             +- github.com/
                 +- contactless
                     +- wb-rules
                     |
                     +- wb-mqtt-confed
                     |
                     +- other go projects...
    
```

This layout is required for building Go projects using wbdev.
`wbdev update-workspace` performs `git pull --ff-only origin <primary-branch>`
for projects that are already cloned.

Updating wbdev
==============

To update wbdev image and wbdev script, use the following commands
(substitute proper path to wbdev script):

```
docker pull contactless/devenv
wget -O /path/to/your/wbdev-script https://raw.githubusercontent.com/contactless/wirenboard/master/wbdev
```

VSCode building and debugging 
=============================

There are VSCode config files in [vscode](vscode) folder. These files can be used to build and debug Wiren Board software. Take some attention on `includePath` settings in `c_cpp_properties.json` and `command` settings in debug tasks in *tasks.json* because they contain sensitive settings for your environment.

For build and run cpp tests you need to install `qemu` and `binfmt` packages on your host.
```
apt install qemu-user-static binfmt-support
```
For debugging you need to install C/C++ extension. In order to debug source code you should stop `wb-mqtt-serial` service on target controller, run `Debug build and copy to wb7` task, go to `Run and debug` VSCode section and select `Remote debug`. In order to debug tests you should install `gdb-multiarch` in container (it's installed automatically on container setup), run `Run tests for debug` task, go to `Run and debug` VSCode section and select `Debug tests`.

Split repositories
==================

Following directories from this repository were moved to separate repositories:
* [common](https://github.com/contactless/wb-common)
* [configs](https://github.com/contactless/wb-configs)
* [utils](https://github.com/contactless/wb-utils)
* [system\_rules](https://github.com/contactless/wb-rules-system)
