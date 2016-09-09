#!/bin/bash

HA_PROXY_DIR=/usr/local/etc/haproxy
LE_DIR=/etc/letsencrypt/live
DOMAINS=$(ls ${LE_DIR})

# update certs for HA Proxy
for DOMAIN in ${DOMAINS}
do
 cat ${LE_DIR}/${DOMAIN}/fullchain.pem ${LE_DIR}/${DOMAIN}/privkey.pem > ${HA_PROXY_DIR}/certs.d/${DOMAIN}.pem
done

# restart haproxy
exec /usr/bin/haproxy-restart
