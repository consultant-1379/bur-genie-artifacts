#!/bin/bash

# Input Variables
volume_id=$1
mount_identifier=$2
disk_id="/dev/disk/by-id/virtio-$(echo $volume_id | cut -c -20)"
vol_name="vol_genie_${mount_identifier}"
vg_name="vg_genie_${mount_identifier}"
mount_point="/local/genie/${mount_identifier}/"
device_name="/dev/${vg_name}/${vol_name}"

function info() {
  echo "[INFO] $1"
}

function error() {
  echo "[ERROR] $1"
}

function is_number() {
    re='^[0-9]+$'
    input_value=$1

    if ! [[ $input_value =~ $re ]] ; then
       return 1
    fi

    return 0
}

function do_mount() {
    info "Volume = ${disk_id}"

    if [ "$(vgs ${vg_name} --nohead)" ]; then
        info "Activating disk group ${vg_name} from previous install"
        vgchange -ay ${vg_name}
        timer=40
        while [ ! -e ${disk_id} ]; do
           info "Waiting for ${device_name}"
           sleep 2
           [ ${timer} -eq 0 ] && { error "Timeout 80s exceeded to activate '${device_name}'"; exit 1; }
           ((timer--))
        done
    else
        # pvcreate ${disk_id}
        info "This is a fresh volume mount: Creating volume group: ${vg_name} with disk id ${disk_id}."

        vgcreate ${vg_name} ${disk_id}

        vg_extents_size=`vgdisplay ${vg_name} -c | awk -F: '{print $14}'`

        is_number ${vg_extents_size}
        command_code=$( echo $? )
        if [[ ${command_code} != "0" ]]; then
            error "Returned vg_extents_size '${vg_extents_size}' is not a valid number."
            exit 1
        fi

        info "Mounting volume with the size ${vg_extents_size}"

        lvcreate --yes -n ${vol_name} ${vg_name} -l ${vg_extents_size}
        command_code=$( echo $? )
        if [[ ${command_code} != "0" ]]; then
            error "Error while mounting volume."
            exit 1
        fi

        mkfs.ext4  /dev/${vg_name}/${vol_name}
    fi

    fsck -t ext4 -y ${device_name}

    if [ ! -d "${mount_point}" ]; then
        echo "${mount_point} not present, it will be created"
        mkdir -p ${mount_point}
    fi

    # verifying if there is any leftover from previous mounting
    ls_list=$(ls ${mount_point})
    for folder in $ls_list
    do
        if [[ "${folder}" = "storage" ]]; then
            info "Cleaning up ${mount_point}"
            rm -rf ${mount_point}/storage
        fi
    done

    if grep ${mount_point} /etc/fstab; then
        info "Fstab entry detected - nothing to do"
    else
        info "Adding fstab entry"
        echo  "/dev/${vg_name}/${vol_name}  ${mount_point}     ext4 defaults  1 2 " >> /etc/fstab
    fi

    mount /dev/${vg_name}/${vol_name} ${mount_point}
    command_code=$( echo $? )
    if [[ ${command_code} != "0" ]]; then
        error "Error while mounting volume."
        exit 1
    fi

    chmod 777 ${mount_point}
    command_code=$( echo $? )
    if [[ ${command_code} != "0" ]]; then
        error "Error while changing permission of ${mount_point}."
        exit 1
    fi

    info "Mounting volume completed successfully"

    return 0
}

# Check input arguments
if [ -z "$2" ] || [ -z "$1" ]; then
    error "Incorrect args given"
    exit 1
fi

# Execute mount function
do_mount
