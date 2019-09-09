#!/bin/sh
pidfile=`cat /var/run/haproxy.pid`
/usr/local/sbin/haproxy -f /usr/local/etc/haproxy/haproxy.cfg -D -p /var/run/haproxy.pid -sf $pidfile
