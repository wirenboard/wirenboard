BOARDS_DIR=$(dirname $(readlink -f "${BASH_SOURCE}"))
TOP_DIR=$(dirname "$BOARDS_DIR")
WORK_DIR="$TOP_DIR/output"
mkdir -p "$WORK_DIR"

board_include() {
	source "$BOARDS_DIR/include/$1"
}

board_override_repos() {
	true
}

export BOARD_PACKAGES=()

[[ -e "${BOARDS_DIR}/${BOARD}.sh" ]] && . "${BOARDS_DIR}/${BOARD}.sh" || {
	echo "Unknown board $BOARD"
	echo "Please specify one of:"
	ls "$BOARDS_DIR" | grep -v 'init_board.sh\|include' | sed 's#\.sh$##; s#^#\t#'
	exit 1
}

ROOTFS_DEFAULT="${WORK_DIR}/rootfs_wb${BOARD}"
ROOTFS=${ROOTFS:-$ROOTFS_DEFAULT}
IMAGES_DIR=${IMAGES_DIR:-${WORK_DIR}/images}

# The rootfs must be built on a CASE-SENSITIVE filesystem. debootstrap unpacks
# packages (e.g. libpam) that ship files differing only in case (pam.7.gz and
# PAM.7.gz); on a case-insensitive filesystem these collide and extraction fails
# with "tar: ... Cannot create symlink to 'PAM.7.gz': File exists". This bites
# when WORK_DIR lives on a macOS bind mount (APFS is case-insensitive by
# default), which is why local builds break on macOS but not on Linux.
#
# When the default output location is case-insensitive, build the rootfs on the
# container's own (case-sensitive) filesystem instead; the images and the
# base-rootfs tarball cache stay in WORK_DIR. Both create_rootfs.sh and
# create_images.sh source this file, so they agree on the relocated path.
# Set ROOTFS (or WB_CASEFS_ROOTFS_DIR) explicitly to override.
dir_is_case_insensitive() {
	local dir="$1" probe ret
	mkdir -p "$dir" 2>/dev/null || return 1
	probe="${dir}/.wb-casecheck.$$"
	rm -f "${probe}a" "${probe}A" 2>/dev/null
	: > "${probe}a" 2>/dev/null || return 1
	ret=1
	if [ -e "${probe}A" ]; then ret=0; fi
	rm -f "${probe}a" "${probe}A" 2>/dev/null
	return $ret
}

if [ "$ROOTFS" = "$ROOTFS_DEFAULT" ] && dir_is_case_insensitive "$WORK_DIR"; then
	ROOTFS="${WB_CASEFS_ROOTFS_DIR:-/var/tmp/wb-rootfs}/rootfs_wb${BOARD}"
	mkdir -p "$(dirname "$ROOTFS")"
	echo "NOTE: $WORK_DIR is on a case-insensitive filesystem (e.g. macOS)." >&2
	echo "      Building rootfs at $ROOTFS instead so debootstrap does not fail" >&2
	echo "      on case-only-differing files; images/cache stay in $WORK_DIR." >&2
	echo "      Set ROOTFS to override." >&2
fi
