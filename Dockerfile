FROM extremeshok/baseimage-alpine:latest AS BUILD

LABEL mantainer="Adrian Kriel <admin@extremeshok.com>" vendor="eXtremeSHOK.com"

RUN \
  echo "**** install nginx ****" \
  && apk-install nginx

RUN \
  echo "**** install msmtp ****" \
  && apk-install msmtp

RUN \
  echo "**** install docker ****" \
  && apk-install docker

RUN \
  echo "**** install bash runtime packages ****" \
  && apk-install \
    bash \
    coreutils \
    curl \
    openssl \
    rsync \
    tzdata

RUN \
  echo "**** install dehydrated ****" \
  && THISVERSION="$(curl --silent -L "https://api.github.com/repos/lukas2511/dehydrated/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')" \
  && echo "$THISVERSION" \
  && THISVERSION="$(echo "$THISVERSION" | sed 's/v//')" \
  && curl --silent -o /tmp/dehydrated.tar.gz -L \
   "https://github.com/lukas2511/dehydrated/releases/download/v${THISVERSION}/dehydrated-${THISVERSION}.tar.gz" \
  && mkdir -p /tmp/dehydrated \
  && tar xfz /tmp/dehydrated.tar.gz -C /tmp/dehydrated \
  && cp -f /tmp/dehydrated/dehydrated*/dehydrated /sbin/dehydrated \
  && chmod 777 /sbin/dehydrated \
  && rm -f /tmp/dehydrated.tar.gz

# add local files
COPY rootfs/ /

RUN \
  echo "**** configure ****" \
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
