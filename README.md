# docker-acme-http2https
letsencrypt support and automatically redirect all http traffic to https

View **docker-compose-sample.yml** in the source repository for usage

# features
Alpine latest with s6
Nginx
dehydrated
check the domains can be accessed before doing acme, prevents wasted acme calls which will fail

## ENVIROMENT VARIBLES

### List of certificates
ACME_DOMAINS=www.domain.com,domain.com;my.otherdomain.net;www.randomdomain.com

### List of docker containers to restart, assume docker socket is connected
ACME_RESTART_CONTAINERS=xshok_baseimagealpine_1;xshok_baseimagealpine_2;xshok_baseimagealpine_3

### Disable checking of external IP connectivity
SKIP_IP_CHECK=no

### Use an external SMTP server, default will use sendmail
SMTP_HOST=smtp.domain.com

SMTP_USER=user@domain.com

SMTP_PASS=securepass

### Notify via email on failure/success
 NOTIFY=admin@domain.com
