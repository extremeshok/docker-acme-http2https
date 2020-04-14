# docker-acme-http2https

https://hub.docker.com/r/extremeshok/acme-http2https

letsencrypt support and automatically redirect all http traffic to https

View **docker-compose-sample.yml** in the source repository for usage

# features
Alpine latest with s6
Nginx
dehydrated ACME client
dehydrated is updated on container start
check the domains can be accessed before doing acme, prevents wasted acme calls which will fail
After acme client has run, sleep for 1 day and watching /acme/domain_list.txt for changes

## ENVIROMENT VARIBLES

### List of certificates
ACME_DOMAINS=www.domain.com,domain.com;my.otherdomain.net;www.randomdomain.com

### List of docker containers to restart, assume docker socket is connected
ACME_RESTART_CONTAINERS=xshok_baseimagealpine_1;xshok_baseimagealpine_2;xshok_baseimagealpine_3
Note: docker socket needs to be mapped, ie.
```
volumes:
  - /var/run/docker.sock:/var/run/docker.sock:rw
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


# example /acme/domain_list.txt
1 certificate per line, first value is the "root aka certificate name"
```
example.org
example.com www.example.com
example.net www.example.net wiki.example.net
service.example.com *.service.example.com
eggs.example.com *.ham.example.com
```
