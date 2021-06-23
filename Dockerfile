FROM extremeshok/baseimage-alpine:latest AS BUILD

LABEL mantainer="Adrian Kriel <admin@extremeshok.com>" vendor="eXtremeSHOK.com"

RUN echo "**** install nginx ****" \
  && apk-install nginx

RUN echo "**** install msmtp ****" \
  && apk-install msmtp

RUN echo "**** install bash runtime packages ****" \
  && apk-install \
    coreutils \
    git \
    inotify-tools \
    openssl \
    rsync \
    tzdata

RUN echo "**** install dehydrated from git ****" \
  && mkdir -p /usr/local/src \
  && cd /usr/local/src \
  && git clone --depth=1 https://github.com/dehydrated-io/dehydrated.git \
  && ln -s /usr/local/src/dehydrated/dehydrated /sbin/dehydrated \
  && chmod 777 /sbin/dehydrated

# add local files
COPY rootfs/ /

RUN echo "**** configure ****" \
  && mkdir -p /acme/certs \
  && mkdir -p /acme/accounts \
  && mkdir -p /var/www/.well-known/acme-challenge \
  && chown -R nginx:nginx /var/www

RUN echo "**** Correct permissions ****" \
  && chmod 0644 /etc/cron.hourly/vhost-autoupdate \
  && chmod +x /etc/services.d/*/run \
  && chmod +x /xshok-*.sh

EXPOSE 80/tcp

WORKDIR /tmp

# "when the SIGTERM signal is sent, it immediately quits and all established connections are closed"
# "graceful stop is triggered when the SIGUSR1 signal is sent "
STOPSIGNAL SIGUSR1

HEALTHCHECK --interval=5s --timeout=5s CMD [ "302" = "$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:80/)" ] || exit 1

ENTRYPOINT ["/init"]
