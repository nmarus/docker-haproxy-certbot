# HAProxy with Certbot

Docker Container with haproxy, certbot, cron, and supervisord configured for
haproxy SSL termination while providing an automated "Let's Encrypt" cert
renewal. Once a cert is added, it will automatically be renewed with no
further interaction.

#### Usage

First some terminology... HAProxy is a reverse proxy load balancer among other
things. Let's Encrypt is a service that allows the creation and renewal of SSL
certificates at no cost. Certbot is a Linux CLI tool for interfacing with the
Let's Encrypt API. Certbot contains it's own http/https server and handles the
authorization process from Let's Encrypt. This container is setup using HAProxy
to redirect the Let's Encrypt callbacks to the certbot http server and all other
requests to the backend server. This configuration of HAProxy is also setup to
do all the SSL termination so that your backend server(s) do not require a SSL
configuration or certificates to be installed.

In order to use this in your environment, you must point all your SSL enabled
domains to the IP Address of this container. This means updating the A Records
for these domains with your DNS Provider. This includes the website name and all
alternate names (i.e. example.com and www.example.com) to point to the
haprox-certbot host. After this is setup, an inbound request for your website is
initially received by HA Proxy. If the request is part of the Let's Encrypt
authentication process, it will redirect that traffic to the local instance of
certbot. Otherwise it  will pass through the request to a backend server (or
servers) through the use of HAProxy ACLs. The details of HAProxy setup are out
of the scope for this README, but some examples are included below to get you
started.

#### Create Container

This will create the haproxy-certbot container. Note that only the inbound ports
for 80 and 443 are exposed.

```bash
docker run -d \
  --restart=always \
  --name haproxy-certbot \
  -p 80:80 \
  -p 443:443 \
  -v /docker/haproxy/haproxy.cfg:/usr/local/etc/haproxy/haproxy.cfg \
  -v /docker/haproxy/letsencrypt:/etc/letsencrypt \
  -v /docker/haproxy/certs.d:/usr/local/etc/haproxy/certs.d \
  nmarus/haproxy-certbot
```

It is important to note the mapping of the 3 volumes in the above command. This
ensures that all non-persistent variable data is not maintained in the container
itself.

The description of the 3 mapped volumes are as follows:

* `/usr/local/etc/haproxy/haproxy.cfg` - The configuration file for HAProxy
* `/etc/letsencrypt` - The directory that Let's Encrypt will store it's
  configuration, certificates and private keys. **It is of significant
  importance that you maintain a backup of this folder in the event the data is
  lost or corrupted.**
* `/usr/local/etc/haproxy/certs.d` - The directory that this container will
  store the processed certs/keys from Let's Encrypt after they have been
  converted into a format that HAProxy can use. This is automatically done at
  each refresh and can also be manually initiated. This volume is not as
  important as the previous as the certs used by HAProxy can be regenerated
  again based on the contents of the letsencrypt folder.

#### Add a New Cert

This will add a new cert using a certbot config that is compatible with the
haproxy config template below. After creating the cert, you should run the
refresh script referenced below to initialize haproxy to use it. After adding
the cert and running the refresh script, no further action is needed.

***This example assumes you named you haproxy-certbot container using the same
name as above when it was created. If not, adjust appropriately.***

```bash
docker exec haproxy-certbot certbot-certonly \
  --domain example.com \
  --domain www.example.com \
  --email nmarus@gmail.com \
  --dry-run
```

*After testing the setup, remove `--dry-run` to generate a live certificate*

#### Renew a Cert
Renewing happens automatically but should you choose to renew manually, you can
do the following.

***This example assumes you named you haproxy-certbot container using the same
name as above when it was created. If not, adjust appropriately.***

```bash
docker exec haproxy-certbot certbot-renew \
  --dry-run
```

*After testing the setup, remove `--dry-run` to refresh a live certificate*

#### Create/Refresh Certs used by haproxy from Let's Encrypt

This will parse and individually concatenate all the certs found in
`/etc/letsencrypt/live` directory into the folder
`/usr/local/etc/haproxy/certs.d`. This additionally will bounce the haproxy
service so that the new certs are active. This also will automatically happen
whenever the cron job runs to refresh the certificates that have been
registered.

```bash
docker exec haproxy-certbot haproxy-refresh
```

***Note: This process will briefly interrupt web traffic to the website behind
the haproxy. At the moment this happens at every run of the cron job or the
'haproxy-refresh' command. This eventually will be more intelligent and only
happen when a certificate is updated.***

### Example haproxy.cfg

##### Using Cluster Backend

This example intercepts the Let's Encrypt validation and redirects to certbot.
Normal traffic is passed to the backend servers. If the request arrives as a
http request, it is redirected to https. If there is not a certificate installed
for the requested website, haproxy will present a self signed default
certificate. This behavior can be modified by adapting the haproxy config file
if so desired.

This example also does not do any routing based on the URL. It assumes that all
domains pointed to this haproxy instance exist on the same backend server(s).
The backend setup in this example consists of 3 web server that haproxy will
load balance against. If there is only a single server, or a different quantity
this can be adjusted in the backend configuration block. This specific example
would be a configuration that could be used in front of a PaaS cluster such
as Flynn.io or Tsuru.io (both of which have their own http router in order to
direct the traffic to the required application).  

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
