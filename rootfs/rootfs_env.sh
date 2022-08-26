services_disable() {
    # This disables startin services when installing packages
    echo exit 101 > ${ROOTFS}/usr/sbin/policy-rc.d
    chmod +x ${ROOTFS}/usr/sbin/policy-rc.d
}

services_enable() {
    rm -f ${ROOTFS}/usr/sbin/policy-rc.d
}

cleanup_chroot() {
    local ret=$?

    echo "Umount proc,dev,dev/pts in rootfs"
    [[ -L ${ROOTFS}/dev/ptmx ]] || umount ${ROOTFS}/dev/ptmx
    umount ${ROOTFS}/dev/pts
    umount ${ROOTFS}/proc
    umount ${ROOTFS}/sys

    services_enable

    return $ret
}

prepare_chroot() {
	# without devpts mount options you will likely end up looking why you can't open
	# new terminal window :)
	echo "Mount /proc, /sys, /dev, /dev/pts"
	mkdir -p ${ROOTFS}/{proc,sys,dev/pts}
	mount --bind /proc ${ROOTFS}/proc
	mount --bind /sys ${ROOTFS}/sys
	mount -t devpts devpts ${ROOTFS}/dev/pts -o "gid=5,mode=666,ptmxmode=0666,newinstance"
	rm -f ${ROOTFS}/dev/ptmx
	ln -s /dev/pts/ptmx ${ROOTFS}/dev/ptmx
	if [[ ! -L ${ROOTFS}/dev/ptmx ]]; then
	    if [[ -e ${ROOTFS}/dev/ptmx ]]; then
	        mount --bind ${ROOTFS}/dev/pts/ptmx ${ROOTFS}/dev/ptmx
	    else
	        ln -s /dev/pts/ptmx ${ROOTFS}/dev/ptmx
	    fi
	fi

	trap cleanup_chroot EXIT
}

# a few shortcuts
chr() {
    chroot ${ROOTFS} "$@"
}

chr_nofail() {
    chroot ${ROOTFS} "$@" || true
}

chr_apt_install() {
    chr apt-get -o Dpkg::Options::=--force-confnew --force-yes install -y "$@" ||
        chr apt-get -o Debug::pkgProblemResolver=yes install -y "$@"
}

chr_apt_update() {
    chr apt-get update
}

chr_apt(){
    chr_apt_install "$@"
}

chr_install_deb() {
    DEB_FILE="$1"
    cp ${DEB_FILE} ${OUTPUT}/
    chr_nofail dpkg -i `basename ${DEB_FILE}`
    rm ${OUTPUT}/`basename ${DEB_FILE}`
}

chr_install_deb_url() {
	DEB_URL="$1"
	DEB_NAME=`basename ${DEB_URL}`
	wget ${DEB_URL} -O ${ROOTFS}/${DEB_NAME}
	chr dpkg -i ${DEB_NAME}
	rm ${ROOTFS}/${DEB_NAME}
}

dbg() {
    chr ls -l /dev/pts
    chr ls -l /proc
}

error_trace() {
	exec >&2
	local ret=$?
	set +o xtrace
	local code="${1:-1}"
	echo "Error in ${BASH_SOURCE[1]}:${BASH_LINENO[0]}. '${BASH_COMMAND}' exited with status $ret"
	# Print out the stack trace described by $function_stack  
	if [[ ${#FUNCNAME[@]} -gt 2 ]]; then
		echo "Call tree:"
		for (( i = 1; i < ${#FUNCNAME[@]} - 1; i++)); do
			echo " $i: ${BASH_SOURCE[$i+1]}:${BASH_LINENO[$i]} ${FUNCNAME[$i]}(...)"
		done
	fi
	echo "Exiting with status ${code}"
	exit "${code}"
}

trap 'error_trace' ERR
set -o errtrace

die() {
	local ret=$?
	>&2 echo "!!! $@"
	[[ $ret == 0 ]] && exit 1 || exit $ret
}

# Runs jq with given arguments and replaces the original file with result
# Example: json_edit '.foo = 123'
json_edit() {
    [[ -e "$JSON" ]] || {
        die "JSON file '$JSON' not found"
        return 1
    }

    local tmp=`mktemp`
    sed 's#//.*##' "$JSON" |    # there are // comments, strip them out
    jq "$@" > "$tmp"
    local ret=$?
    [[ "$ret" == 0 ]] && cat "$tmp" > "$JSON"
    rm "$tmp"
    return $ret
}
