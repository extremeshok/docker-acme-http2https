FROM extremeshok/baseimage-alpine:latest AS BUILD

LABEL mantainer="Adrian Kriel <admin@extremeshok.com>" vendor="eXtremeSHOK.com"

RUN echo "**** install nginx ****" \
  && apk-install nginx

RUN echo "**** install msmtp ****" \
  && apk-install msmtp

RUN \
  echo "**** install docker ****" \
  && apk-install docker

RUN echo "**** install bash runtime packages ****" \
  && apk-install \
    bash \
    coreutils \
    curl \
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
  && mkdir -p /certs \
  && mkdir -p /acme/certs \
  && mkdir -p /acme/accounts \
  && mkdir -p /var/www/acme-challenge \
  && chown -R nginx:nginx /var/www \
  && chmod 777 /xshok-acme.sh \
  && chmod 777 /xshok-acmehook.sh

EXPOSE 80/tcp

WORKDIR /tmp

ENTRYPOINT ["/init"]
