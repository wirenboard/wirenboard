#!/bin/bash

echo "USAGE: $0 <release> [files]"

LAST_RELEASE=`github-release info -u contactless -r wirenboard | grep releases -A1 | tail -n 1 | cut -d, -f1 | cut -c3-`
echo "Last release: ${LAST_RELEASE}" 


RELEASE=$1

github-release release -u contactless -r wirenboard  -t $RELEASE || /bin/true

shift

# iterate
while test ${#} -gt 0
do
  echo "About to upload $1 to $RELEASE"
  github-release upload -u contactless -r wirenboard  -t $RELEASE -f $1 -n `basename $1`
  echo "done"
  echo

  shift
done
