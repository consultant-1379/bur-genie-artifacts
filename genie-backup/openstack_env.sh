#!/bin/bash
# Download the certificate: wget http://192.168.255.253/nwci/site/ssl_cert/certificate-1.0.1.crt
export OS_USERNAME=`echo YnVjaW53Y2kK | base64 --decode`
export OS_CACERT=./certificate-1.0.1.crt
export OS_AUTH_URL=https://10.2.63.251:13000/v2.0
export OS_PASSWORD=`echo YnVjMU5XYzEtMjAxNwo= | base64 --decode`
export BUR_SERVER_NAME=genie_bur
export OS_PROJECT_NAME=GENIE
