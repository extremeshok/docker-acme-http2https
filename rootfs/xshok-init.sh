#!/bin/bash

echo "Update Dehydrated"
cd /usr/local/src/dehydrated || exit
git pull --depth=1

if [ ! -z "$NOTIFY" ] && [ ! -z "$SMTP_HOST" ] && [ ! -z "$SMTP_USER" ] && [ ! -z "$SMTP_PASS" ] ; then
  # Generating Remote SMTP config
cat << EOF >> /etc/msmtprc
defaults
port ${SMTP_PORT:-587}
tls on
tls_trust_file /etc/ssl/certs/ca-certificates.crt

account remote
host ${SMTP_HOST}
from ${SMTP_USER}
auth on
user ${SMTP_USER}
password ${SMTP_PASS}

account default : remote

EOF
fi

exit 0
