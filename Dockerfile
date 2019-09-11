# haproxy2.0.5 alpine with certbot
FROM haproxy:2.0.5-alpine

# Install Supervisor, cron, openssl and certbot
RUN apk --update add --no-cache supervisor dcron certbot openssl && \
    rm -rf /tmp/* /var/tmp/*

# Setup Supervisor
RUN mkdir -p /var/log/supervisor
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# Setup HAProxy and Certbot
RUN mkdir -p /usr/local/etc/haproxy/certs.d
RUN mkdir -p /usr/local/etc/letsencrypt
RUN mkdir -p /config
COPY cron-certbot-renew.sh /etc/periodic/daily/certbot-renew
COPY cron-delete-month-old-log-files.sh /etc/periodic/monthly/delete-month-old-log-files
COPY haproxy.cfg /tmp/haproxy.cfg
COPY cli.ini /usr/local/etc/letsencrypt/cli.ini
COPY cli-manual.ini /usr/local/etc/letsencrypt/cli-manual.ini
COPY haproxy-refresh.sh /usr/bin/haproxy-refresh
COPY haproxy-restart.sh /usr/bin/haproxy-restart
COPY certbot-certonly.sh /usr/bin/certbot-certonly
COPY certbot-certonly-dns.sh /usr/bin/certbot-certonly-dns
COPY certbot-renew.sh /usr/bin/certbot-renew
RUN chmod +x /usr/bin/haproxy-refresh /usr/bin/haproxy-restart /usr/bin/certbot-certonly /usr/bin/certbot-certonly-dns /usr/bin/certbot-renew /etc/periodic/daily/certbot-renew /etc/periodic/monthly/delete-month-old-log-files

# Add startup script
COPY start.sh /start.sh
RUN chmod 775 /start.sh

# Start
CMD ["/start.sh"]
