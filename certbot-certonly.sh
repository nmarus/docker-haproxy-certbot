#!/bin/bash

/usr/bin/certbot certonly -c /usr/local/etc/letsencrypt/cli.ini "$@"
