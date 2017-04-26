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

[[ -e "${BOARDS_DIR}/${BOARD}.sh" ]] && . "${BOARDS_DIR}/${BOARD}.sh" || {
	echo "Unknown board $BOARD"
	echo "Please specify one of:"
	ls "$BOARDS_DIR" | grep -v 'init_board.sh\|include' | sed 's#\.sh$##; s#^#\t#'
	exit 1
}

ROOTFS=${ROOTFS:-${WORK_DIR}/rootfs_wb${BOARD}}
IMAGES_DIR=${IMAGES_DIR:-${WORK_DIR}/images}
