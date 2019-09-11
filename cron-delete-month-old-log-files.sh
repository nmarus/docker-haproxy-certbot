#!/bin/sh

find /var/log/ -name "*.log*" -type f -mtime +30 -delete
