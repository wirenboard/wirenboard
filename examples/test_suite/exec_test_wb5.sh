#!/bin/bash
set -e

if [ $# -ne 1 ]
then
  echo "USAGE: $0 <IP addr>"
  exit 1
fi

HOST=$1
CREDENTIALS_FNAME=Commissioning-30b68b322b7c.json
PASSWORD="wirenboard"

echo "Connecting to $HOST ..."

ssh-keygen -f ~/.ssh/known_hosts -R $HOST
sshpass -p ${PASSWORD} scp  -o StrictHostKeyChecking=no common/${CREDENTIALS_FNAME} root@${HOST}:/dev/shm/credentials.json
sshpass -p ${PASSWORD} ssh  -o StrictHostKeyChecking=no -t root@${HOST} "ln -s -f /dev/shm/credentials.json /usr/lib/wb-test-suite/common/${CREDENTIALS_FNAME}; service ntp restart; cd /usr/lib/wb-test-suite/wb5_func_test; bash"
