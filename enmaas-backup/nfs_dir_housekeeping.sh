#!/usr/bin/env bash

DIR=$(dirname "$0")

function error {
    echo $@
    exit 10
}
BURHOST='10.1.90.10'
BURUSER=cinder

# Run obsolete_cleaner.sh on ${CUSTOMER}
ssh ${BURUSER}@${BURHOST} "/usr/local/bin/obsolete_cleaner.sh ${CUSTOMER}"

exit $?
