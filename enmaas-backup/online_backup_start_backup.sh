#!/usr/bin/env bash

DIR=$(dirname "$0")

function error {
    echo $@
    exit 10
}

[[ -z ${CUSTOMER} ]] && echo "error CUSTOMER not defined"

OUT=$( $DIR/run_backup_stages.py --customer=$CUSTOMER --stage=BACKUP --stdout )
RET=$?
#OUT="ID: 123453524  TAG: Backup_1544118136_Staging01_1815_CVRestore_2018126"
INFO=$(grep ^ID <<< "$OUT" )
ID=$(awk ' { print $2 } ' <<<$INFO) 
#ID=124453524
TAG=$(awk ' { print $4 } ' <<<$INFO)
#TAG=comcast_18.15_iso_1.64.121__20181212_0300

echo "BACKUP_ID=$ID" >> out.properties
echo "BACKUP_TAG=$TAG" >> out.properties

echo "$OUT"
exit $RET
