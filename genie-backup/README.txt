HOW TO USE:

1. Run the genie-backup-deploy.sh script to send the required scripts to genie-bur server (192.168.255.249).
   - Note that genie-backup-deploy.sh might require changes.

2. Go to genie-bur server (tsocks ssh...).

3. Copy the scripts mount_volumes.sh and volume_backup.sh to the path /usr/local/bin.
    - The script volume_backup.sh uses mount_volumes.sh.
	- If you want to change this path, update the wrapper automationScripts/volume_backup_onsite.sh from where these scripts are being called.

4. Double check the wrappers inside automationScripts.
	- If you need to update the wrappers, excute the script deploy-wrappers.sh on genie-bur server.

5 - When running the volume_backup.sh script, please comment the "remove_old_openstack_vol_backups" function.
    After finishing the test, remove the backups created by testing.
