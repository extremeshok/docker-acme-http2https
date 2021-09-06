# docker-acme-http2https

https://hub.docker.com/r/extremeshok/acme-http2https

letsencrypt support which will automatically redirect all http traffic to https

View **docker-compose-sample.yml** in the source repository for usage

# testing of acme.sh

# features
* Alpine latest with s6
* HEALTHCHECK activated
* Nginx
* redirects http to httpS
* acme.sh ACME client
* acme.sh is updated on container start
* After acme client has run, sleep for 1 day and watching /acme/domain_list.txt for changes
* check the domains can be accessed before doing acme, prevents wasted acme calls which will fail
* Support for both /certs and /var/www/vhosts directory layouts
* Optional generation of 4096bit DHPARAM, otherwise will use a bundled (default) 4096 dhparam
* Generates a default /root/.rnd (fixes: Can't load /root/.rnd into RNG)

## OPTIONS

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

### Use an external SMTP server, default will use sendmail
SMTP_HOST=smtp.domain.com

SMTP_USER=user@domain.com

SMTP_PASS=securepass

### Notify via email on failure/success
 NOTIFY=admin@domain.com
