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

# RUN echo "**** install dehydrated from git ****" \
#   && mkdir -p /usr/local/src \
#   && cd /usr/local/src \
#   && git clone --depth=1 https://github.com/dehydrated-io/dehydrated.git \
#   && ln -s /usr/local/src/dehydrated/dehydrated /sbin/dehydrated \
#   && chmod 777 /sbin/dehydrated

RUN echo "**** install acme.sh from git ****" \
  && mkdir -p /usr/local/src \
  && cd /usr/local/src \
  && git clone --depth=1 https://github.com/acmesh-official/acme.sh.git \
  && ln -s /usr/local/src/acme.sh/acme.sh /sbin/acme.sh \
  && chmod 777 /sbin/acme.sh

# add local files
COPY rootfs/ /

RUN echo "**** configure ****" \
  && mkdir -p /acme/certs \
  && mkdir -p /acme/accounts \
  && mkdir -p /var/www/.well-known/acme-challenge \
  && chown -R nginx:nginx /var/www

RUN echo "**** Correct permissions ****" \
  && chmod 755 /etc/services.d/*/run \
  && chmod 755 /xshok-*.sh

EXPOSE 80/tcp

WORKDIR /tmp

# "when the SIGTERM signal is sent, it immediately quits and all established connections are closed"
# "graceful stop is triggered when the SIGUSR1 signal is sent "
STOPSIGNAL SIGUSR1

HEALTHCHECK --interval=5s --timeout=5s CMD [ "302" = "$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:80/)" ] || exit 1

ENTRYPOINT ["/init"]
