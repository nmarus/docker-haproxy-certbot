# haproxy1.6.9 with certbot
FROM debian:jessie

RUN apt-get update && apt-get install -y libssl1.0.0 libpcre3 --no-install-recommends && rm -rf /var/lib/apt/lists/*

# Setup HAProxy
ENV HAPROXY_MAJOR 1.6
ENV HAPROXY_VERSION 1.6.9
RUN buildDeps='curl gcc libc6-dev libpcre3-dev libssl-dev make' \
  && set -x \
  && apt-get update && apt-get install -y $buildDeps --no-install-recommends && rm -rf /var/lib/apt/lists/* \
  && curl -SL "http://www.haproxy.org/download/${HAPROXY_MAJOR}/src/haproxy-${HAPROXY_VERSION}.tar.gz" -o haproxy.tar.gz \
  && mkdir -p /usr/src/haproxy \
  && tar -xzf haproxy.tar.gz -C /usr/src/haproxy --strip-components=1 \
  && rm haproxy.tar.gz \
  && make -C /usr/src/haproxy \
    TARGET=linux2628 \
    USE_PCRE=1 PCREDIR= \
    USE_OPENSSL=1 \
    USE_ZLIB=1 \
    all \
    install-bin \
  && mkdir -p /config \
  && mkdir -p /usr/local/etc/haproxy \
  && cp -R /usr/src/haproxy/examples/errorfiles /usr/local/etc/haproxy/errors \
  && rm -rf /usr/src/haproxy \
  && apt-get purge -y --auto-remove $buildDeps

# Install Supervisor, cron, libnl-utils, net-tools, iptables
RUN apt-get update && apt-get install -y supervisor cron libnl-utils net-tools iptables && \
  apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Setup Supervisor
RUN mkdir -p /var/log/supervisor
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# Install Certbot
RUN echo 'deb http://ftp.debian.org/debian jessie-backports main' > /etc/apt/sources.list.d/jessie-backports.list
RUN apt-get update && apt-get install -y certbot -t jessie-backports && \
  apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Setup Certbot
RUN mkdir -p /usr/local/etc/haproxy/certs.d
RUN mkdir -p /usr/local/etc/letsencrypt
COPY certbot.cron /etc/cron.d/certbot
COPY cli.ini /usr/local/etc/letsencrypt/cli.ini
COPY haproxy-refresh.sh /usr/bin/haproxy-refresh
COPY haproxy-restart.sh /usr/bin/haproxy-restart
COPY certbot-certonly.sh /usr/bin/certbot-certonly
COPY certbot-renew.sh /usr/bin/certbot-renew
RUN chmod +x /usr/bin/haproxy-refresh /usr/bin/haproxy-restart /usr/bin/certbot-certonly /usr/bin/certbot-renew

# Add startup script
COPY start.sh /start.sh
RUN chmod +x /start.sh

# Start
CMD ["/start.sh"]
