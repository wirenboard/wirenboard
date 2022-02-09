#!/bin/bash

LIBS_PATH=/lib/
DT_COMPAT_LIST=`tr < /proc/device-tree/compatible '\000' '\n'`

for compat in $DT_COMPAT_LIST; do
    case "$compat" in
        "contactless,imx28-wirenboard50" )
            LIB=wb5
            break
            ;;
        "contactless,imx28-wirenboard52" )
            LIB=wb5
            break
            ;;
        "contactless,imx28-wirenboard55" )
            LIB=wb5
            break
            ;;
        "contactless,imx28-wirenboard58" )
            LIB=wb5
            break
            ;;
        "contactless,imx6ul-wirenboard60" )
            LIB=wb6
            break
            ;;
        "contactless,imx6ul-wirenboard61" )
            LIB=wb6
            break
            ;;
        "wirenboard,wirenboard-700" )
            LIB=wb7
            break
            ;;
    esac
done

source ${LIBS_PATH}/libupdate.${LIB}.sh || {
    echo "Unknown platform"
    exit 1
}
