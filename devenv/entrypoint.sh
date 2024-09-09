#!/bin/bash
set -u -e

cmd=user
root=
shell_cmd=

echo "$DEV_TERM" >/.term
export TERM="$DEV_TERM"

if [ $# -gt 0 ]; then
    cmd="$1"
    shift
fi

case "$cmd" in
    user|chuser|root|chroot)
        if [[ $# -eq 0 ]]; then
            shell_cmd="/bin/bash -l"
        fi
        ;;
esac

DEV_UID="${DEV_UID:-1000}"
DEV_USER="${DEV_USER:-user}"
DEV_GID="${DEV_GID:-$DEV_UID}"
DEV_GROUP="${DEV_GROUP:-$DEV_USER}"
DEB_BUILD_OPTIONS="${DEB_BUILD_OPTIONS:-}"

WBDEV_BUILD_METHOD=${WBDEV_BUILD_METHOD:-}
WBDEV_USE_UNSTABLE_DEPS=${WBDEV_USE_UNSTABLE_DEPS:-""}
WBDEV_CCACHE_DIR=${WBDEV_CCACHE_DIR:-""}
WBDEV_CCACHE_MAX_SIZE=${WBDEV_CCACHE_MAX_SIZE:-"10G"}

WBDEV_TARGET_BOARD=${WBDEV_TARGET_BOARD:-wb6}
WBDEV_TARGET_ARCH=${WBDEV_TARGET_ARCH:-armhf}
WBDEV_INSTALL_DEPS=${WBDEV_INSTALL_DEPS:-no}
WBDEV_TARGET_RELEASE=${WBDEV_TARGET_RELEASE:-"bullseye"}
WBDEV_TARGET=${WBDEV_TARGET:-""}
WBDEV_TESTING_SETS=${WBDEV_TESTING_SETS:-""}

PYBUILD_TEST_ARGS="${WBDEV_PYBUILD_TEST_ARGS:-}"

QEMU_ARCH=${QEMU_ARCH:-"arm"}

# Parse parameters supplied via env variables
case "$WBDEV_BUILD_METHOD" in
sbuild|qemuchroot)
    ;;
*)
    echo "Warning: sbuild+multiarch will be used. Set WBDEV_BUILD_METHOD=qemuchroot for legacy virtualized build."
    WBDEV_BUILD_METHOD="sbuild"
esac

# current-<arch> targets are (or should be) used by CI (jenkins)

case "$WBDEV_TARGET" in
stretch-armhf|wb6)
    WBDEV_TARGET_BOARD="wb6"
    WBDEV_TARGET_ARCH="armhf"
    WBDEV_TARGET_RELEASE="stretch"
    ;;
stretch-armel|wb5|current-armel)
    WBDEV_TARGET_BOARD="wb5"
    WBDEV_TARGET_ARCH="armel"
    WBDEV_TARGET_RELEASE="stretch"
    ;;
stretch-host|host|stretch-amd64)
    WBDEV_TARGET_BOARD="host"
    WBDEV_TARGET_ARCH="amd64"
    WBDEV_TARGET_RELEASE="stretch"
    ;;
bullseye-armhf|current-armhf)
    WBDEV_TARGET_BOARD="wb6"
    WBDEV_TARGET_ARCH="armhf"
    WBDEV_TARGET_RELEASE="bullseye"
    ROOTFS_PKG_CONFIG_PATH="/rootfs/bullseye-armhf/usr/lib/arm-linux-gnueabihf/pkgconfig"
    ;;
bullseye-arm64|current-arm64|wb8)
    WBDEV_TARGET_BOARD="wb8"
    WBDEV_TARGET_ARCH="arm64"
    WBDEV_TARGET_RELEASE="bullseye"
    QEMU_ARCH="aarch64"
    ROOTFS_PKG_CONFIG_PATH="/rootfs/bullseye-arm64/usr/lib/aarch64-linux-gnu/pkgconfig"
    ;;
bullseye-host|bullseye-amd64|current-amd64)
    WBDEV_TARGET_BOARD="host"
    WBDEV_TARGET_ARCH="amd64"
    WBDEV_TARGET_RELEASE="bullseye"
    ;;
esac

WBDEV_TARGET_REPO_RELEASE=${WBDEV_TARGET_REPO_RELEASE:-"stable"}
WBDEV_TARGET_REPO_PREFIX=${WBDEV_TARGET_REPO_PREFIX:-""}

ROOTFS="/rootfs/${WBDEV_TARGET_RELEASE}-${WBDEV_TARGET_ARCH}"

export WORKSPACE_DIR="/home/$DEV_USER/wbdev"
export GOPATH="$WORKSPACE_DIR"/go

if [ -n "$WBDEV_CCACHE_DIR" ]; then
    cat <<EOF >/etc/ccache.conf
cache_dir = $WBDEV_CCACHE_DIR
max_size = $WBDEV_CCACHE_MAX_SIZE
compression = true
compression_level = 6
hard_link = false
umask = 002
EOF
    export PATH="/usr/lib/ccache:$PATH"
fi

rm -f /.devdir $ROOTFS/.devdir
if [ -n "$DEV_DIR" ]; then
    if [ -n "$shell_cmd" ]; then
        echo "$DEV_DIR" >/.devdir
        if [[ -d "$ROOTFS" ]]; then
            echo "$DEV_DIR" >"$ROOTFS/.devdir"
        fi
    elif ! cd "$DEV_DIR"; then
        echo "WARNING: can't chdir to $DEV_DIR"
    fi
fi

if ! getent group "$DEV_GROUP" >& /dev/null; then
    addgroup --gid "$DEV_GID" "$DEV_GROUP" >& /dev/null
fi

if ! getent passwd "$DEV_USER" >& /dev/null; then
    adduser --uid "$DEV_UID" --gecos "" --gid "$DEV_GID" --disabled-password --no-create-home "$DEV_USER" >& /dev/null
fi

# setup Go environment (for non-login shell cases)
. /etc/profile.d/wbdev_profile.sh

devsudo () {
    # Note: here we use sudo because
    # 1 - current debian su doesn't support --session-command flag
    #     thus causing 'no job control' errors in subshell
    # 2 - su -c causes argument expansion problems with "$@"
    # Also we use 'env' here because without it (i.e. when
    # utilizing sudo's own environment passing mechanism)
    # PATH gets overridden in the subshell
    sudo -E -u "$DEV_USER" env HOME="/home/$DEV_USER" PATH="$PATH" "$@"
}

chu () {
    devsudo proot -R $ROOTFS -q qemu-${QEMU_ARCH}-static $shell_cmd "$@"
}

chr () {
    proot -S $ROOTFS -q qemu-${QEMU_ARCH}-static -b "/home/$DEV_USER:/home/$DEV_USER" $shell_cmd "$@"
}

loadprojects() {
    n_projects=0
    while read projs[$n_projects] proj_base_dirs[$n_projects] \
               proj_urls[$n_projects] proj_branches[$n_projects] proj_how[$n_projects]; do
        n_projects=$((n_projects+1))
    done </projects.list
}

update_workspace() {
    loadprojects
    devsudo mkdir -p "$WORKSPACE_DIR" "$WORKSPACE_DIR/go"
    for ((n=0; n < n_projects; n++)); do
        proj="${projs[n]}"
        proj_base_dir="$WORKSPACE_DIR"/"${proj_base_dirs[$n]}"
        proj_dir="$proj_base_dir"/"$proj"
        proj_url="${proj_urls[n]}"
        proj_branch="${proj_branches[n]}"
        if [ ! -d "$proj_dir" ]; then
            devsudo mkdir -p "$proj_dir"
            (
                cd "$proj_base_dir"
                if ! devsudo git clone "$proj_url" "$proj"; then
                    echo "WARNING: git clone failed for $proj (url: $proj_url)" 1>&2
                    continue
                fi
            )
        fi
        if [ -d "$proj_dir" ]; then
            (
                cd "$proj_dir"
                if ! devsudo git checkout "$proj_branch"; then
                    echo "WARNING: git checkout failed for $proj (url: $proj_url)" 1>&2
                    continue
                fi
                if ! devsudo git pull --ff-only origin "$proj_branch"; then
                    echo "WARNING: git pull --ff-only failed for $proj (url: $proj_url)" 1>&2
                    continue
                fi
            )
        fi
    done
}

die() {
    echo "$@" >&2
    exit 1
}

wb_repo_path() {
    PLATFORM=$1
    PREFIX=${2:-$WBDEV_TARGET_REPO_PREFIX}

    if [[ -n "${PREFIX}" ]]; then
        echo "${PREFIX}/${PLATFORM}"
    else
        echo "${PLATFORM}"
    fi
}

platform_has_suite() {
    local SUITE=$1
    local PLATFORM=$2

    local URL="http://deb.wirenboard.com/$(wb_repo_path $PLATFORM)/dists/${SUITE}/Release"
    local HTTP_CODE
    echo "Checking $URL..." >&2
    HTTP_CODE=`curl --silent --head --output /dev/null --write-out '%{http_code}\n' $URL`
    local CURL_STATUS=$?

    if [[ "$CURL_STATUS" != "0" ]]; then
        die "Failed to retrieve $URL, curl returned $CURL_STATUS"
    fi

    # logic is the following:
    #  - code=404 -> no such suite
    #  - 200<=code<400 -> ok
    #  - else -> failure
    echo "Server returned $HTTP_CODE" >&2
    if [[ $HTTP_CODE -eq 404 ]]; then
        return 1  # no such suite
    elif [[ $HTTP_CODE -ge 200 ]] && [[ $HTTP_CODE -lt 400 ]]; then
        return 0  # suite found
    else
        die "Failed to retrieve $URL, server returned $HTTP_CODE"
    fi
}

has_arch_all() {
    grep -q '^Architecture: all$' debian/control
}

has_arch_any() {
    grep '^Architecture:' debian/control | grep -vq '^Architecture: all$'
}

get_stable_repo_spec() {
    local STABLE_REPO_SPEC=""

    if [ "${WBDEV_TARGET_BOARD}" == "host" ]; then
        echo "host target selected, using dev-tools repo as stable" >&2
        STABLE_REPO_SPEC="deb http://deb.wirenboard.com/dev-tools ${WBDEV_TARGET_REPO_RELEASE} main"
    else
        local WB_REPO_PLATFORM="${WBDEV_TARGET_BOARD}/${WBDEV_TARGET_RELEASE}"

        if platform_has_suite "${WBDEV_TARGET_REPO_RELEASE}" "${WB_REPO_PLATFORM}"; then
            echo "Platform $WB_REPO_PLATFORM has ${WBDEV_TARGET_REPO_RELEASE} suite, add it to build" >&2
            STABLE_REPO_SPEC="deb [arch=armhf,armel,arm64,amd64] http://deb.wirenboard.com/$(wb_repo_path $WB_REPO_PLATFORM) ${WBDEV_TARGET_REPO_RELEASE} main"
        else
            echo "WARNING: Platform ${WB_REPO_PLATFORM} doesn't have ${WBDEV_TARGET_REPO_RELEASE} suite! (building for pre-production?)" >&2
        fi
    fi

    echo "$STABLE_REPO_SPEC"
}

get_unstable_repo_spec() {
    local UNSTABLE_REPO_SPEC=""
    local WB_REPO_PLATFORM="${WBDEV_TARGET_BOARD}/${WBDEV_TARGET_RELEASE}"

    if [ "${WBDEV_TARGET_BOARD}" != "host" ]; then
        if platform_has_suite unstable $WB_REPO_PLATFORM; then
            echo "Platform ${WB_REPO_PLATFORM} has unstable suite, add it to build" >&2
            UNSTABLE_REPO_SPEC="deb [arch=armhf,armel,amd64,arm64] http://deb.wirenboard.com/$(wb_repo_path $WB_REPO_PLATFORM) unstable main"
        else
            echo "Platform ${WB_REPO_PLATFORM} doesn't have unstable suite" >&2
        fi
    fi

    echo "$UNSTABLE_REPO_SPEC"
}

sbuild_buildpackage() {
    local ARCH=$1
    shift

    export _DEB_BUILD_OPTIONS=${DEB_BUILD_OPTIONS}
    export _PYBUILD_TEST_ARGS=${PYBUILD_TEST_ARGS}

    SBUILD_ARGS=(-c "${WBDEV_TARGET_RELEASE}-amd64-sbuild")
    SBUILD_ARGS+=(--bd-uninstallable-explainer="apt")
    if [ -n "$WBDEV_USE_UNSTABLE_DEPS" ]; then
        SBUILD_ARGS+=(--extra-repository="$(get_unstable_repo_spec)")
    fi
    SBUILD_ARGS+=(--extra-repository="$(get_stable_repo_spec)")
    if [ -n "$WBDEV_TESTING_SETS" ]; then
        IFS=',' read -ra testing_sets <<< "$WBDEV_TESTING_SETS"
        for testing_set in "${testing_sets[@]}"; do
            local TESTING_SET_REPO_SPEC="deb [arch=armhf,armel,amd64,arm64] http://deb.wirenboard.com/all experimental.${testing_set} main"
            SBUILD_ARGS+=(--extra-repository="$TESTING_SET_REPO_SPEC")
        done
    fi
    SBUILD_ARGS+=(--no-apt-upgrade --no-apt-distupgrade)
    SBUILD_ARGS+=(-d "${WBDEV_TARGET_RELEASE}")
    SBUILD_ARGS+=("$@")

    if has_arch_all; then
        echo "Build packages for Architecture: all"
        sbuild --arch-all --no-arch-any "${SBUILD_ARGS[@]}"
    else
        echo "No Architecture: all packages in this source"
    fi

    if has_arch_any; then
        echo "Build packages for binary architectures"
        sbuild --no-arch-all --arch-any --host="$ARCH" "${SBUILD_ARGS[@]}"
    else
        echo "No binary architecture packages in this source"
    fi
}

print_target_info() {
    echo "Build target: ${WBDEV_TARGET_RELEASE}-${WBDEV_TARGET_ARCH} (board ${WBDEV_TARGET_BOARD})"
    echo "You can change it by setting WBDEV_TARGET variable (e.g. 'stretch-armhf'/'stretch-armel' or 'wb6'/'wb5')"
}

case "$cmd" in
    user)
        if [ -n "$shell_cmd" ]; then
            su - "$DEV_USER"
        else
            devsudo "$@"
        fi
        ;;
    ndeb)
        if [ "$WBDEV_BUILD_METHOD" = "sbuild" ]; then
            echo "WARNING: wbdev ndeb with sbuild is deprecated."
            echo "  To build arch-all package for Wiren Board, use wbdev cdeb instead."
            echo "  To build for dev machine, use wbdev cdeb with WBDEV_TARGET=bullseye-host."
            echo ""

            sbuild_buildpackage amd64 "$@"
        else
            if [ "$WBDEV_INSTALL_DEPS" = "yes" ]; then
                apt-get update || apt-get update # workaround for missing apt diff files
                mk-build-deps -ir -t "apt-get --force-yes -y"
            fi
            devsudo dpkg-buildpackage -us -uc "$@"
        fi
        ;;
    gdeb)
        print_target_info
        case "$WBDEV_TARGET_ARCH" in
            armel)
                devsudo CC=arm-linux-gnueabi-gcc dpkg-buildpackage -b -aarmel -us -uc "$@"
                ;;
            armhf)
                devsudo CC=arm-linux-gnueabihf-gcc dpkg-buildpackage -b -aarmhf -us -uc "$@"
                ;;
            arm64)
                devsudo CC=aarch64-linux-gnu-gcc dpkg-buildpackage -b -aarm64 -us -uc "$@"
                ;;
            *)
                echo "Unsupported target arch: $WBDEV_TARGET_ARCH"
                exit 1
                ;;
        esac
        ;;
    hmake)
        if [ "$WBDEV_INSTALL_DEPS" = "yes" ]; then
            apt-get update
            mk-build-deps -ir -t "apt-get --force-yes -y"
        fi
        devsudo make "$@"
        ;;
    root)
        $shell_cmd "$@"
        ;;
    chuser)
        print_target_info
        chu "$@"
        ;;
    make)
        print_target_info
        if [ "$WBDEV_INSTALL_DEPS" = "yes" ]; then
            chr apt-get update
            chr mk-build-deps -ir -t "apt-get --force-yes -y"
        fi
        chu make "$@"
        ;;
    compiledb)
        print_target_info
        if [ -n "$WBDEV_USE_UNSTABLE_DEPS" ]; then
            chr sh -c "echo '$(get_unstable_repo_spec)' > /etc/apt/sources.list.d/wirenboard.list"
        else
            chr sh -c "echo '$(get_stable_repo_spec)' > /etc/apt/sources.list.d/wirenboard.list"
        fi
        chr apt-get update
        chr mk-build-deps -ir -t "apt-get --force-yes -y"
        if [ -f CMakeLists.txt ]; then
            chu mkdir -p build; ( cd build && PKG_CONFIG_PATH=$ROOTFS_PKG_CONFIG_PATH cmake -DCMAKE_EXPORT_COMPILE_COMMANDS=ON .. )
            mv build/compile_commands.json compile_commands.json
        elif [ -f Makefile ]; then
            chu make -Bnwk | compiledb -o compile_commands.json
        fi
        $shell_cmd "$@"
        ;;
    cdeb)
        print_target_info
        if [ "$WBDEV_BUILD_METHOD" = "sbuild" ]; then
            sbuild_buildpackage ${WBDEV_TARGET_ARCH} "$@"
        else
            if [ "$WBDEV_INSTALL_DEPS" = "yes" ]; then
                chr apt-get update
                chr mk-build-deps -ir -t "apt-get --force-yes -y"
            fi
            chu dpkg-buildpackage -us -uc "$@"
        fi
        ;;
    chroot)
        print_target_info
        chr "$@"
        ;;
    update-workspace)
        update_workspace
        ;;
    *)
        echo "Unknown command '$cmd'" 1>&2
        exit 1
esac
