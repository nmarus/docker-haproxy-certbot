#!/bin/sh

nl-qdisc-add --dev=lo --parent=1:4 --id=40: --update plug --buffer
/usr/local/sbin/haproxy -f /config/haproxy.cfg -D -p /var/run/haproxy.pid -sf $(cat /var/run/haproxy.pid)
nl-qdisc-add --dev=lo --parent=1:4 --id=40: --update plug --release-indefinite
