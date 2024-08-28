#!/bin/bash

# Local variables

baseDir=`dirname "$0"`

download_location="$( mktemp -d )"
os_cert_location="${download_location}/os_cert.crt"

backupMountDir="backup"
volume_backup_name="genie_backup"
volume_backup_status=""
dateStamp=`date +%Y-%m-%d`
backupName="${volume_backup_name}_${dateStamp}"
nfs_backup_dir="/data1/rpcbackups"
nfs_genie_folder_name="genie_volume"

os_username=YnVjaW53Y2kK
os_password=YnVjMU5XYzEtMjAxNwo=
os_cacert=http://192.168.255.253/nwci/site/ssl_cert/certificate-1.0.1.crt
os_auth_url=https://10.2.63.251:13000/v2.0

log=""
backupStatus=""
serverId=""
volumeId=""
nfs_volume_backup_path=""

genie_backup_volume_size=20

bur_server_name="genie_bur"
os_project_name="GENIE"

mailSubject="Genie backup notification"
mailTo="fo-enmaas@ericsson.com"
mailUrl="https://172.31.2.5/v1/emailservice/send"
mailFrom="genie-vol-backup-onsite@ericsson.com"

nfs_host="cinder@10.1.90.10"

CURL_INSECURE="curl --insecure"

function info() {
  echo "[INFO] $1"
}

function error() {
  echo "[ERROR] $1"
}

function warn() {
  echo "[WARN] $1"
}

function send_email_notification(){
    # Function to send alerts as an email to the admin
    if [[ -z $@ ]]; then 
        warn "can not send email with empty notification."
        return
    fi 

    notification_text=$@
    mailBody="<p>${dateStamp} - Notification from Genie Backup operation:</br>Backup Tag: ${backupName}</br></p><p>${notification_text}</p>"
    maildata='{"personalizations": [{"to": [{"email": "'${mailTo}'"}]}],"from": {"email": "'${mailFrom}'"}, "subject": "'${mailSubject}'","content": [{"type": "text/html", "value": "'${mailBody}'"}]}'

    curl -v -k --request POST \
      --url "${mailUrl}" \
      --header 'cache-control: no-cache' \
      --header 'content-type: application/json' \
      --data "${maildata}"

    info "notification email sent."
}

function send_successful_email(){
    # Function to send successful backup operation email.
    message="Backup Operation done successfully."
    send_email_notification ${message}
}

function send_failure_email(){
    # Function to send a backup failed operation email.
    if [[ -z $@ ]]; then 
        warn "can not send email with empty notification."
        return
    fi 
    send_email_notification $@
}

function check_exit_code(){
    # Function used to check the exit code from an executed command if an error exit
    command_code=$1
    log=$2
    if [[ "${command_code}" != "0" ]]; then
        log="Error code ${command_code} raised while executing the script due to: ${log}"
        error ${log}
        send_failure_email ${log}
        clean_up ${download_location}
        exit 1
    fi
}

function clean_up() {
    # Function to clean up after the deployment
    download_location=$1
    rm -rf ${download_location}
}

function download_os_cert_file() {
    # Function used to download the os cert file that should be used for the deployment to execute on
    os_cacert=$1
    cert_download_location=$2
    ${CURL_INSECURE} -o ${cert_download_location} ${os_cacert}

    command_code=$( echo $? )
    check_exit_code ${command_code} "Error to download certification file."
}

function set_openstack_env() {
    # Function to set the OpenStack ENV
    os_cert=$1
    username=$( echo ${os_username} | base64 --decode )
    password=$( echo ${os_password} | base64 --decode )
    export OS_AUTH_URL=${os_auth_url}
    export OS_USERNAME=${username}
    export OS_PASSWORD="${password}"
    export OS_PROJECT_NAME=${os_project_name}
    if [[ ${os_cert} != "" ]];then
        export OS_CACERT=${os_cert}
    fi
}

function get_volume_backup_status(){
    # Function to get the status of the backup volume
    volume_backup_status=$( openstack volume list | grep -w ${volume_backup_name} | awk -F '|' '{print $4}' | tr -d '[:space:]' )
    info "Volume backup status: ${volume_backup_status}"
}

function openstack_remove_volume() {
    # Function to detach OpenStack volume
    serverId=$1
    volumeId=$2

    openstack server remove volume ${serverId} ${volumeId}

    command_code=$( echo $? )
    check_exit_code ${command_code} "Error to remove volume ${volumeId} from OpenStack."
}

function create_the_backup_volume() {
    # Function to create the backup Volume, checks if the volume is already created

    get_volume_backup_status

    info "${volume_backup_name} status: ${volume_backup_status}"

    if [[ "${volume_backup_status}" = "available" ]]; then
        info "Volume already created"
        return
    fi

    volumeId=$( openstack volume list | grep "${volume_backup_name} " | awk '{print $2}' )

    if [[ "${volumeId}" != "" ]]; then
        info "OpenStack volume '${volumeId}' seems to be already created on server '${serverId}'.
         Trying to detach it."
        openstack_remove_volume ${serverId} ${volumeId}
    else
        info "Creating ${volume_backup_name} volume"
        openstack volume create ${volume_backup_name} --size ${genie_backup_volume_size}
    fi

    # Check the volume is in an available state
    loop=0
    while [[ ${loop} -le 60 ]]; do
        get_volume_backup_status
        if [[ ${volume_backup_status} = "available" ]]; then
            info "Backup volume is created and available"
            break
        fi
        warn "Backup volume is not in 'available' state, waiting and checking again"
        sleep 10
        loop=$((loop + 1))
    done
}

function attach_volume_to_server() {
    # Function to attach the volume to the Server
    serverId=$1
    volumeId=$2

    openstack server add volume ${serverId} ${volumeId}

    command_code=$( echo $? )
    check_exit_code ${command_code} "Error while attaching volume to OpenStack."

    # Check is the Volume Attached to the Server
    loop=0
    while [[ ${loop} -le 60 ]]; do
        get_volume_backup_status
        if [[ ${volume_backup_status} = "in-use" ]]; then
            info "${volume_backup_name} is 'in-use' and ready for use"
            break
        fi
        warn "Volume is not attached, waiting and retrying"
        sleep 10
        loop=$((loop + 1))
    done
}

function detach_volume_from_server() {
    # Function to attach the volume to the Server
    serverId=$1
    volumeId=$2

    sudo umount /local/genie/${backupMountDir}

    command_code=$( echo $? )
    check_exit_code ${command_code} "Failed to unmount /local/genie/${backupMountDir}"

    openstack_remove_volume ${serverId} ${volumeId}

    # Check is the Volume detached to the Server
    loop=0
    while [[ ${loop} -le 60 ]]; do
        get_volume_backup_status
        if [[ ${volume_backup_status} = "available" ]]; then
            info "${volume_backup_name} is detached from ${serverId}"
            break
        fi
        warn "Volume is still attached, waiting and retrying"
        sleep 10
        loop=$((loop + 1))
    done
}

function mount_volume_to_server() {
    # Function to add the Volume to the Server
    volumeId=$1
    sudo chmod 777 ${baseDir}/mount_volumes.sh
    sudo ${baseDir}/mount_volumes.sh ${volumeId} ${backupMountDir}

    command_code=$( echo $? )
    check_exit_code ${command_code} "Failed to mount server."
}

function copy_to_backup(){
    # Function to copy the storage volume to the backup volume
    rsync -av bucinwci@192.168.255.249:/local/genie/storage /local/genie/${backupMountDir} --exclude lost+found
    command_code=$( echo $? )
    check_exit_code ${command_code} "Error while copying backup using rsync."
}

function get_backup_status() {
    backupStatus=$( openstack volume backup list | grep ${backupName} | awk -F '|' '{print $5}' | tr -d '[:space:]' )
    info "Backup status: ${backupStatus}"
}

function delete_backup() {
    openstack volume backup delete ${backupName}
    loop=0
    while [[ ${loop} -le 180 ]]; do
        get_backup_status
        if [[ ${backupStatus} = "" ]]; then
            info "${backupName} was deleted"
            break
        else
            warn "Backup not deleted yet, waiting and retrying"
            sleep 10
            loop=$((loop + 1))
        fi
    done
}

function create_openstack_backup() {
    info "Checking if a backup for today already exists"

    get_backup_status

    if [[ ${backupStatus} = "available" ]]; then
        info "Found a backup for today, it will be deleted"
        delete_backup
    else
        info "No backup for today found, one will be created"
    fi

    info "Creating backup ${backupName}"
    openstack volume backup create --name ${backupName} ${volume_backup_name}

    command_code=$( echo $? )
    check_exit_code ${command_code} "Failed to execute OpenStack backup command"

    loop=0
    while [[ ${loop} -le 180 ]]; do
        get_backup_status

        if [[ ${backupStatus} = "available" ]]; then
            info "${backup_name} was created"
            break
        else
            warn "Backup not created yet, waiting and retrying"
            sleep 10
            loop=$((loop + 1))
        fi
    done

    get_backup_status

    if [[ ${backupStatus} = "" ]]; then
        check_exit_code 1 "${backup_name} was NOT created"
    fi
}

function get_volume_backup_id(){
    backup_id=$(openstack volume backup show -c id ${backupName} -f value)

    if [[ ${backup_id} = "" ]]; then
        check_exit_code 1 "Backup ID not found for backup ${backupName}"
    fi

    info "Volume backup id retrieved ${backup_id}."
}

function add_new_genie_backup(){
    root_backup_path="${nfs_backup_dir}/${nfs_genie_folder_name}"

    info "Resetting previous genie backup folder"
    ssh ${nfs_host} [ -d ${root_backup_path} ] ; [ $? = 0 ] && ssh ${nfs_host} rm -rf ${root_backup_path}
	ssh ${nfs_host} mkdir ${root_backup_path}

    info "Add the new backup folder"

    backup_path="${root_backup_path}/${backupName}"
    ssh ${nfs_host} mkdir ${backup_path}

    command_code=$( echo $? )
    check_exit_code ${command_code} "Error to create the path for the new genie backup
    ${backup_path}"

    info "Get the newly created OpenStack backup path"
    get_volume_backup_id
    nfs_volume_backup_path="${nfs_backup_dir}/${backup_id:0:2}/${backup_id:2:2}/${backup_id}"

    info "Create a symbolic link from the OpenStack backup to the new folder"


    create_symbolic_link_for_openstack_volume_cmd="ln -sf ${nfs_volume_backup_path} ${backup_path}/${backupName}_${backup_id}"
    ssh ${nfs_host} "${create_symbolic_link_for_openstack_volume_cmd}"

    command_code=$( echo $? )
    check_exit_code ${command_code} "Error to create a symbolic link for path ${nfs_volume_backup_path}"

    info "Create a BACKUP_OK file flag in a created backup."

    ssh ${nfs_host} "touch ${backup_path}/BACKUP_OK"

    command_code=$( echo $? )
    check_exit_code ${command_code} "Error while creating backup ok flag."
}

function remove_old_openstack_vol_backups() {
    backups=($(openstack volume backup list --volume ${volume_backup_name} -f value -c Name))

    for i in {0..2}; do echo ${backups[@]}; unset backups[0]; done

    for backup_name in $backups
    do
        info "Removing volume backup ${backup_name}"
        openstack volume backup delete ${backup_name}

        command_code=$( echo $? )
        check_exit_code ${command_code} "Error while removing volume backup ${backup_name}."
    done
}

# Main Calls
if [[ ! -z "${os_cacert}" ]]; then
    info "Downloading os certification from ${os_cacert} to ${os_cert_location}"
    download_os_cert_file ${os_cacert} ${os_cert_location}
fi

info "Setting the openstack env variables"
set_openstack_env ${os_cert_location}

serverId=$( openstack server list | grep "${bur_server_name} " | awk '{print $2}' )
info "Getting server id"
info "ServerId = ${serverId}"

info "Creating the backup volume"
create_the_backup_volume

info "Getting volume id"
volumeId=$( openstack volume list | grep "${volume_backup_name} " | awk '{print $2}' )
info "VolumeId = ${volumeId}"

info "Attaching the volume to the server"
attach_volume_to_server ${serverId} ${volumeId}

info "Mounting the volume filesystem to the server"
mount_volume_to_server ${volumeId}

info "Copy the storage content to the backup volume"
copy_to_backup

info "Detaching backup volume"
detach_volume_from_server ${serverId} ${volumeId}

info "Checking if there are more than 3 backups."
remove_old_openstack_vol_backups

info "Creating openstack backup"
create_openstack_backup genie_backup_${dateStamp} genie_backup

info "Adding the new genie backup to the filesystem and include BACKUP_OK flag"
add_new_genie_backup

info "Sending email to admin"
send_successful_email "Backup completed successfully"

info "Finished......"

