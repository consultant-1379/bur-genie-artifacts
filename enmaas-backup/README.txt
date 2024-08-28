HOW TO USE:

1. Run the enmaas-backup-deploy.sh script to send the required scripts to genie-bur server (192
.168.255.249).
   - Note that enmaas-backup-deploy.sh might require changes.

2. Go to genie-bur server (tsocks ssh...).

3. Zip the folder automationScripts and name it bur-customer_name.zip.
   zip -r bur-customer_name.zip ./automationScripts

To update all customers with the same zip file on genie-bur server:

1. Zip the automationScripts folder given a generic name, such as wrappers.zip.
   zip -r wrappers.zip ./automationScripts

2. Get the list of customer names.

3. Run the copy command:

tee ./bur-cellcom.zip ./bur-chariton.zip ./bur-charter.zip ./bur-comcast.zip ./bur-cww.zip ./bur-ekn.zip ./bur-frontier.zip ./bur-ksw.zip ./bur-nextech.zip ./bur-sprint.zip ./bur-staging01.zip ./bur-staging05.zip ./bur-tbaytel.zip ./bur-verizon.zip < ./wrappers.zip >/dev/null
