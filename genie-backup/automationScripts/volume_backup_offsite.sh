#!/usr/bin/env bash

DIR=$(dirname "$0")

function error {
    echo $@
    exit 10
}
JOBHOST='10.1.90.10'
JOBUSER=cinder


# Run obsolete_cleaner.sh on ${CUSTOMER}
ssh ${JOBUSER}@${JOBHOST} "bur --script_option 1 --customer_name 'genie_vol_bkp'"

exit $?
