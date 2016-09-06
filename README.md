# HAProxy with Certbot
Docker Container with haproxy, certbot, cron, and supervisord configured for
haproxy SSL termination while providing an automated "Let's Encrypt" cert
renewal. Once a cert is added, it will automatically be renewed with no
further interaction.

#### Create Container

This will create the haproxy-certbot container

```bash
docker run -d \
  --restart=always \
  --name haproxy-certbot \
  --hostname haproxy-certbot \
  -p 80:80 \
  -p 443:443 \
  -v /docker/haproxy/haproxy.cfg:/usr/local/etc/haproxy/haproxy.cfg \
  -v /docker/haproxy/letsencrypt:/etc/letsencrypt \
  -v /docker/haproxy/certs.d:/usr/local/etc/haproxy/certs.d \
  nmarus/haproxy-certbot
```

#### Add a New Cert

This will add a new cert using a certbot config that is compatible with the
haproxy config template below. After creating the cert, you should run the
refresh script referenced below to initialize haproxy to use it. After adding
the cert and running the refresh script, no further action is needed.

```bash
docker exec haproxy-certbot certbot certonly \
  --standalone \
  --domain example.com \
  --email nmarus@gmail.com \
  --agree-tos \
  --http-01-port 8080 \
  --tls-sni-01-port 8443 \
  --non-interactive \
  --standalone-supported-challenges http-01 \
  --dry-run
```

*Remove `--dry-run` to generate a live certificate*

#### Renew a Cert

```bash
docker exec haproxy-certbot certbot renew \
  --dry-run
```

*Remove `--dry-run` to refresh a live certificate*

#### Create/Refresh Certs used by haproxy from Let's Encrypt

This will parse and individually concatenate all the certs found in
`/etc/letsencrypt/live` directory into the folder
`/usr/local/etc/haproxy/certs.d`. This additionally will bounce the haproxy
service so that the new certs are active. This also will automatically happen
whenever the cron job runs to refresh the certificates that have been
registered.

```bash
docker exec haproxy-certbot /usr/local/etc/haproxy/refresh.sh
```

### Example haproxy.cfg

##### Using Cluster Backend

This example intercepts the Let's Encrypt validation and redirects to certbot.
Normal traffic is passed to the backend servers.
Normal http traffic is redirected to https.

```
global
  maxconn 1028

  log 127.0.0.1 local0
  log 127.0.0.1 local1 notice

  ca-base /etc/ssl/certs
  crt-base /etc/ssl/private

  ssl-default-bind-ciphers ECDH+AESGCM:DH+AESGCM:ECDH+AES256:DH+AES256:ECDH+AES128:DH+AES:ECDH+3DES:DH+3DES:RSA+AESGCM:RSA+AES:RSA+3DES:!aNULL:!MD5:!DSS
  ssl-default-bind-options no-sslv3

defaults
  option forwardfor

  log global

  timeout connect 5000ms
  timeout client 50000ms
  timeout server 50000ms

  stats enable
  stats uri /stats
  stats realm Haproxy\ Statistics
  stats auth admin:haproxy

frontend http-in
  bind *:80
  mode http

  reqadd X-Forwarded-Proto:\ http

  acl letsencrypt_http_acl path_beg /.well-known/acme-challenge/
  use_backend letsencrypt_http if letsencrypt_http_acl
  redirect scheme https if !letsencrypt_http_acl

  default_backend my_http_backend

frontend https_in
  bind *:443 ssl crt /usr/local/etc/haproxy/default.pem crt /usr/local/etc/haproxy/certs.d ciphers ECDHE-RSA-AES256-SHA:RC4-SHA:RC4:HIGH:!MD5:!aNULL:!EDH:!AESGCM
  mode http

  reqadd X-Forwarded-Proto:\ https

  default_backend my_http_backend

backend letsencrypt_http
  mode http
  server letsencrypt_http_srv 127.0.0.1:8080

backend my_http_backend
  mode http
  balance leastconn
  option tcp-check
  option log-health-checks
  server server1 1.1.1.1:80 check port 80
  server server2 2.2.2.2:80 check port 80
  server server3 3.3.3.3:80 check port 80
```
