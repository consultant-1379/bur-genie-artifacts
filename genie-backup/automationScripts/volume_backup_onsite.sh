#!/usr/bin/env bash

DIR=$(dirname "$0")

function error {
    echo $@
    exit 10
}
JOBHOST='192.168.255.249'
JOBUSER=bucinwci

# Run onsite IP backup
ssh ${JOBUSER}@${JOBHOST} "/usr/local/bin/volume_backup.sh"

exit $?
