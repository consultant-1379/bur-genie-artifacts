#!/usr/bin/env bash

DIR=$(dirname "$0")

function info() {
  echo "[INFO] $1"
}

function warn() {
  echo "[WARN] $1"
}

function error() {
    echo $@
    exit 10
}

[[ -z $CUSTOMER ]] && error CUSTOMER not defined
[[ -z $BACKUP_TAG ]] && error BACKUP_TAG not defined
[[ -z $BACKUP_ID ]] && error BACKUP_ID not defined

mailSubject="ENMaaS on-site backup notification from customer $CUSTOMER"
mailTo="fo-enmaas@ericsson.com"
mailUrl="https://172.31.2.5/v1/emailservice/send"
mailFrom="$CUSTOMER@no-reply.ericsson.net"

function send_email_notification(){
    # Function to send alerts as an email to the admin
    if [[ -z $@ ]]; then
        warn "Can not send email with empty notification."
        return
    fi

    notification_text=$@
    mailBody="<p>${dateStamp} - Notification from on-site ENMaaS backup operation:</br>Backup Tag: $BACKUP_TAG</br>Customer Name: $CUSTOMER</br>Backup ID: $BACKUP_ID</br></p><p>${notification_text}</p>"

    maildata='{"personalizations": [{"to": [{"email": "'${mailTo}'"}]}],"from": {"email":
    "'${mailFrom}'"}, "subject": "'${mailSubject}'","content": [{"type": "text/html", "value":
    "'${mailBody}'"}]}'

    curl -v -k --request POST \
      --url "${mailUrl}" \
      --header 'cache-control: no-cache' \
      --header 'content-type: application/json' \
      --data "${maildata}"

    info "Notification email sent."
}

function send_successful_email(){
    # Function to send successful backup operation email.
    message="On-site Backup Operation done successfully."
    send_email_notification ${message}
}

function check_exit_code(){
    # function used to check the exit code from an executed command if an error exit
    command_code=$1
    log=$2
    if [[ "${command_code}" != "0" ]]; then
        log="Error code ${command_code} raised while executing the script due to: ${log}"
        error ${log}
        exit 1
    fi
}

$DIR/run_backup_stages.py --customer=$CUSTOMER --stage=METADATA --tag=$BACKUP_TAG --id=$BACKUP_ID --stdout

command_code=$( echo $? )
check_exit_code ${command_code} "Error executing the backup metadata stage."

send_successful_email
