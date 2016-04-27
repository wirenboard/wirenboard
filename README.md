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
wget https://raw.githubusercontent.com/contactless/wirenboard/master/wbdev
chmod +x wbdev
```

In order to use the script, you must
[install docker](http://docs.docker.com/engine/installation/ubuntulinux/)
first.

The development environment consists "host" environment which is
Debian "jessie" Linux image used to build Python noarch packages,
Go-based packages such as `wb-rules` and `wb-mqtt-confed` and
`wb-mqtt-homeui` frontend. It also contains qemu chroot environment
used to build C++-based armel packages such as those from
`wb-homa-drivers` project.

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
`make` there to rebuild the image (note though that it may take 40
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
* `wbdev gdeb` builds an armel deb from a Go project in the current
  directory (should be used under a wbdev workspace, see **WBDEV
  Workspace** below).
* `wbdev cdeb` builds an armel deb from a C++ project in the current
  directory.
* `wbdev make [args...]` invokes `make` in qemu chroot environment in
  the current directory.
* `wbdev hmake [args...]` invokes `make` in host user mode in the
  current directory. Use it to build x86_64 binaries and to do `wbdev hmake test`
  on C++ projects.
* `wbdev update-workspace` creates or updates wbdev workspace in
  `~/wbdev` (see **WBDEV Workspace** below).

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
