#!/usr/bin/env bash

echo "ZIPPING"
zip -r ./genie-backup.zip ./automationScripts

echo "MOVING ZIP"
mv ./genie-backup.zip /var/www/html/nwci/bur/scripts/genie-backup
