#!/bin/bash -x

# Variables
#CUSTOMER=${CUSTOMER}
JOBID=$(date +%Y%m%d%H%M%S)
TEMPDIR=/tmp/${JOBID}
LOGDIR=${TEMPDIR}/logs
LOGFILE=${LOGDIR}/${CUSTOMER}_upload.log
BURHOST='10.1.90.10'
BURUSER=cinder
NUMCPU=8
NUMCPUTRANS=8
NUMTHREADS=8
SCRIPTOPTION=1
SLEEPTIME='300s'

# Connect to offsite and try to clear blob_cache
ssh cloud-user@10.1.100.4 'sudo umount /offsite_azure \
  && echo "offsite_azure unmounted" \
  && sleep 60 \
  && sudo blobfuse /offsite_azure \
  --tmp-path=/blob_cache \
  -o attr_timeout=240 \
  -o entry_timeout=240 \
  -o negative_timeout=120 \
  --config-file=/root/connection.cfg \
  -o allow_other \
  || echo "failed to unmount offsite_azure" '

# Connect to offsite and check if /offsite_azure is mounted
ssh cloud-user@10.1.100.4 'mount | grep offsite_azure' || exit 1

# 1
# Create TEMPDIR locally with script inside it
mkdir ${TEMPDIR}

# 
echo "#!/bin/bash
if [ \$(uname) == SunOS ] ; then
  NOHUPBIN=/usr/gnu/bin/nohup
else
  NOHUPBIN=\$(which nohup)
fi
\${NOHUPBIN} /export/home/cinder/.local/bin/bur \\
  --script_option ${SCRIPTOPTION} \\
  --customer_name ${CUSTOMER} \\
  --number_threads ${NUMTHREADS} \\
  --number_processors ${NUMCPU} \\
  --number_transfer_processors ${NUMCPUTRANS} \\
  --log_root_path ${LOGDIR} > ${TEMPDIR}/nohup.out 2>&1 & echo \$! > ${TEMPDIR}/PID
if [ -z ${TEMPDIR}/PID ] ; then
  echo "bur was not started, exiting"
  exit 1
fi
" >> ${TEMPDIR}/burwrapper.sh

echo "#!/bin/bash
PIDID=\$(cat ${TEMPDIR}/PID)
if [ -d /proc/\${PIDID} ] ; then
  echo "PID \${PIDID} is running, sleep more"
  exit 255
fi
if ! grep 'ERROR - E' ${LOGFILE} > /dev/null \\
  && grep 'Elapsed time to complete the backup' ${LOGFILE} ; then
  echo "exit code is \$?"
  echo "My logs are"
  cat ${TEMPDIR}/nohup.out
  exit 0
else
  echo "Bur command failed"
  echo "The logs are"
  cat ${TEMPDIR}/nohup.out
  exit 1
fi
" > ${TEMPDIR}/checkstate.sh

chmod +x ${TEMPDIR}/burwrapper.sh
chmod +x ${TEMPDIR}/checkstate.sh

# 2
# Copy TEMPDIR to BURHOST
scp -r ${TEMPDIR} ${BURUSER}@${BURHOST}:/tmp/

# 3
# Run temp.script in background; Save logs in temp.dir; Keep PID in temp.dir;
ssh ${BURUSER}@${BURHOST} "${TEMPDIR}/burwrapper.sh"
if [ $? == 1 ] ; then
  echo "bur was not started, exiting"
  exit 1
fi

# 4
# Sleep; Open connection. Check PID with checkstate.sh
# If PID exists > close connection and sleep again
# TODO: add increment for this part, to wait reasonable amount of time

EXITCODE=255
while [ $EXITCODE == 255 ] ; do
sleep ${SLEEPTIME}
ssh ${BURUSER}@${BURHOST} "${TEMPDIR}/checkstate.sh"
EXITCODE=$?
echo PID ${PIDID} is running, sleep more
done

exit $EXITCODE
