#!/bin/bash

set -e

HA_PROXY_DIR=/usr/local/etc/haproxy
TEMP_DIR=/tmp

PASSWORD=$(openssl rand -base64 32)
SUBJ="/C=US/ST=somewhere/L=someplace/O=haproxy/OU=haproxy/CN=haproxy.selfsigned.invalid"

KEY=${TEMP_DIR}/haproxy_key.pem
CERT=${TEMP_DIR}/haproxy_cert.pem
CSR=${TEMP_DIR}/haproxy.csr
DEFAULT_PEM=${HA_PROXY_DIR}/default.pem
CONFIG=/config/haproxy.cfg

# Check if config file for haproxy exists
if [ ! -e ${CONFIG} ]; then
  echo "${CONFIG} not found"
  exit 1
fi

# Check if default.pem has been created
if [ ! -e ${DEFAULT_PEM} ]; then
  openssl genrsa -des3 -passout pass:${PASSWORD} -out ${KEY} 2048 &> /dev/null
  openssl req -new -key ${KEY} -passin pass:${PASSWORD} -out ${CSR} -subj ${SUBJ} &> /dev/null
  cp ${KEY} ${KEY}.org &> /dev/null
  openssl rsa -in ${KEY}.org -passin pass:${PASSWORD} -out ${KEY} &> /dev/null
  openssl x509 -req -days 3650 -in ${CSR} -signkey ${KEY} -out ${CERT} &> /dev/null
  cat ${CERT} ${KEY} > ${DEFAULT_PEM}
  echo ${PASSWORD} > /password.txt
fi

# Mark Syn Packets
IP=$(echo `ifconfig eth0 2>/dev/null|awk '/inet addr:/ {print $2}'|sed 's/addr://'`)
/sbin/iptables -t mangle -I OUTPUT -p tcp -s ${IP} --syn -j MARK --set-mark 1

# Set up the queuing discipline
tc qdisc add dev lo root handle 1: prio bands 4
tc qdisc add dev lo parent 1:1 handle 10: pfifo limit 1000
tc qdisc add dev lo parent 1:2 handle 20: pfifo limit 1000
tc qdisc add dev lo parent 1:3 handle 30: pfifo limit 1000

# Create a plug qdisc with 32 meg of buffer
nl-qdisc-add --dev=lo --parent=1:4 --id=40: plug --limit 33554432
# Release the plug
nl-qdisc-add --dev=lo --parent=1:4 --id=40: --update plug --release-indefinite

# Set up the filter, any packet marked with "1" will be
# directed to the plug
tc filter add dev lo protocol ip parent 1:0 prio 1 handle 1 fw classid 1:4

# Run Supervisor
exec /usr/bin/supervisord
