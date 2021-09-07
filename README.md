# docker-acme-http2https

https://hub.docker.com/r/extremeshok/acme-http2https

letsencrypt support which will automatically redirect all http traffic to https

View **docker-compose-sample.yml** in the source repository for usage

# features
* Alpine latest with s6
* HEALTHCHECK activated
* Nginx
* redirects http to httpS
* acme.sh ACME client
* acme.sh is updated on container start
* After acme client has run, sleep for 1 day and watching /acme/domain_list.txt for changes
* check the domains and alias domains can be accessed before doing acme, prevents wasted acme calls which will fail
* automatically removes alias domains which do not resolve from the certificate
* Support for both /certs and /var/www/vhosts directory layouts
* Default to generate a 4096bit DHPARAM, Set GENERATE_DHPARAM=false to use the bundled 4096 dhparam
* Generates a default /root/.rnd (fixes: Can't load /root/.rnd into RNG)

## OPTIONS with defaults
REGISTERED_EMAIL=admin@extremeshok.com
DEFAULT_CA=letsencrypt
ENABLE_STAGING=no
ENABLE_DEBUG=no
SKIP_IP_CHECK=no
SKIP_DOMAIN_CHECK=no
GENERATE_DHPARAM=yes
UPDATE_ACME=yes
RESTART_DOCKER=no
ACME_RESTART_CONTAINERS=
ACME_DOMAINS=

### /certs dir
If detected, will copy the certificates and keys to /certs/domain.com/

### /var/www/vhosts
If detected, will copy the certificates and keys to /var/www/vhosts/domain.com/certs/

### List of certificates, optional
ACME_DOMAINS=www.domain.com,domain.com;my.otherdomain.net;www.randomdomain.com

### List of docker containers to restart, assume docker socket is connected
ACME_RESTART_CONTAINERS=xshok_baseimagealpine_1;xshok_baseimagealpine_2;xshok_baseimagealpine_3
Note: docker socket needs to be mapped, ie.
```
volumes:
  - /var/run/docker.sock:/var/run/docker.sock:rw
```

### example /acme/domain_list.txt
1 certificate per line, first value is the "root aka certificate name"
```
example.org
example.com www.example.com
example.net www.example.net wiki.example.net
service.example.com *.service.example.com
eggs.example.com *.ham.example.com
```

### Enable generation of 4096bit DHPARAM
GENERATE_DHPARAM=yes
Note: will take a long time

### Disable checking of external IP connectivity
SKIP_IP_CHECK=no

# MAIL NOTIFICATIONS ARE CURRENTLY DISABLED

## MAIL options with defaults
NOTIFY=REGISTERED_EMAIL
SMTP_HOST=
SMTP_PORT=587
SMTP_USER=
SMTP_PASS=

### Use an external SMTP server, default will use sendmail
SMTP_HOST=smtp.domain.com

SMTP_USER=user@domain.com

SMTP_PASS=securepass

### Notify via email on failure/success
 NOTIFY=admin@domain.com
