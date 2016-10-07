#!/bin/bash
PREV_NUM=`aptly snapshot list -sort=time -raw | tail -n 1 | cut -d. -f2`
PREFIX=`aptly snapshot list -sort=time -raw | tail -n 1 | cut -d. -f1`

CUR_NUM=$((PREV_NUM+1))
NAME="${PREFIX}.${CUR_NUM}"
echo "new snapshot: $NAME"
aptly snapshot create $NAME from repo wirenboard-release
aptly publish switch wheezy s3:releases.contactless.ru: $NAME

