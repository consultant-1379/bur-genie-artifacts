GENIE_BUR_ACCESS_KEY_PATH=/media/sf_shared/genie_bur.pem
GROOVY_NAME=NMaaS_Backup.groovy
GROOVY_PATH=/media/sf_shared/bur-genie-artifacts/eiffel/$GROOVY_NAME
CENTOS_USER=centos
GENIE_BUR_IP=192.168.255.249
GENIE_BUR_TEMP_DIR=/data1/groovy-scp
GENIE_BUR_EIFFEL_DIR=/local/genie/storage/docker/ve

echo "Copying to GenieBur server."
tsocks scp -i $GENIE_BUR_ACCESS_KEY_PATH $GROOVY_PATH $CENTOS_USER@$GENIE_BUR_IP:$GENIE_BUR_TEMP_DIR

echo "Moving to Eiffel dir."
tsocks ssh -i $GENIE_BUR_ACCESS_KEY_PATH $CENTOS_USER@$GENIE_BUR_IP sudo cp $GENIE_BUR_TEMP_DIR/$GROOVY_NAME $GENIE_BUR_EIFFEL_DIR

