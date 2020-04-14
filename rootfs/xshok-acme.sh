#!/bin/bash
################################################################################
# This is property of eXtremeSHOK.com
# You are free to use, modify and distribute, however you may not remove this notice.
# Copyright (c) Adrian Jon Kriel :: admin@extremeshok.com
################################################################################

# Place a file "/acme/domain_list.txt" with a list of domains
# oe set the env varible "ACME_DOMAINS"
#ACME_DOMAINS="something.com;anotherdomain.com,www.anotherdomain.com"

get_ipv4(){
  local IPV4=
  local IPV4_SRCS=
  local TRY=
  IPV4_SRCS[0]="api.ipify.org"
  IPV4_SRCS[1]="ifconfig.co"
  IPV4_SRCS[2]="icanhazip.com"
  IPV4_SRCS[3]="v4.ident.me"
  IPV4_SRCS[4]="ipecho.net/plain"
  until [[ ! -z ${IPV4} ]] || [[ ${TRY} -ge 120 ]]; do
    IPV4=$(curl --connect-timeout 3 -m 10 -L4s ${IPV4_SRCS[$RANDOM % ${#IPV4_SRCS[@]} ]} | grep -E "^((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$")
    [[ ! -z ${TRY} ]] && sleep 1
    TRY=$((TRY+1))
  done
  echo "${IPV4}"
}

if [ -f "/acme/lock" ] ; then
  echo "Removing lock"
  rm -f /acme/lock
fi

if [[ ! "${SKIP_IP_CHECK}" =~ ^([yY][eE][sS]|[yY])+$ ]]; then
  echo "========== Testing IPv4 webserver access =========="
  IPV4=$(get_ipv4)
  # shellcheck disable=SC2002
  UUID="xshok-$(date +%s)"
  echo "$UUID" > /var/www/acme-challenge/uuid.html
  HTTPONLINE="false";
  until [[ ! -z ${HTTPONLINE} ]] || [[ ${TRY} -ge 120 ]]; do
    echo "Testing Localhost"
    if curl --silent "http://127.0.01/" >/dev/null 2>&1 ; then
      echo "Testing IPv4 with UUID: ${IPV4}"
      UUID_RESULT=$(curl -L4s "http://${IPV4}/.well-known/acme-challenge/uuid.html")
      if [ "$UUID" == "$UUID_RESULT" ] ; then
        HTTPONLINE="true";
      fi
    fi
    [[ ! -z ${HTTPONLINE} ]] && sleep 3
    TRY=$((TRY+1))
  done
else
  HTTPONLINE="true";
fi

## DHPARAM
if [ "$GENERATE_DHPARAM" == "yes" ] ; then
  if [ ! -f "/acme/certs/dhparam.pem" ] ; then
    echo "========== Generating 4096 dhparam =========="
    openssl dhparam -out /acme/certs/dhparam.pem 4096
    echo "Completed"
  elif ! grep -q "BEGIN DH PARAMETERS" /certs/dhparam.pem || ! grep -q "END DH PARAMETERS" /certs/dhparam.pem ; then
    echo "========== Generating New 4096 dhparam =========="
    rm -f /acme/certs/dhparam.pem
    openssl dhparam -out /acme/certs/dhparam.pem 4096
    echo "Completed"
  fi
fi

if [[ ! -z ${HTTPONLINE} ]]  ; then
  ## UPDATE
  echo "========== UPDATE DEHYDRATED =========="
  cd /usr/local/src/dehydrated || exit
  git pull --depth=1
  ## DEHYDRATED
  echo "========== DEHYDRATED RUNNING =========="
  dehydrated --register --accept-terms
  if [ -f "/acme/domain_list.txt" ] ; then
    echo "-- Sign/renew new/changed/expiring certificates from /acme/domain_list.txt"
    dehydrated --cron
  else
    if [[ ! -z $ACME_DOMAINS ]]; then
      echo "-- Sign/renew new/changed/expiring certificates"
      if [[ $ACME_DOMAINS =~ [\,\;] ]]; then
        domain_array=$(echo "$ACME_DOMAINS" | tr ";" "\\n")
        for domain in $domain_array ; do
          #check the domains can be accessed, prevents wasted acme calls which will fail
          domain_micro_array=$(echo "$domain" | tr "," "\\n")
          for domain_micro in $domain_micro_array ; do
            UUID="xshok-$(date +%s)"
            echo "$UUID" > /var/www/acme-challenge/uuid.html
            DOMAINONLINE="false"
            until [[ ! -z ${DOMAINONLINE} ]] || [[ ${TRY} -ge 120 ]]; do
              echo "Testing Localhost"
              if curl --silent "http://127.0.01/" >/dev/null 2>&1 ; then
                echo "Testing Domain with UUID: ${domain_micro}"
                UUID_RESULT=$(curl -L4s "http://${domain_micro}/.well-known/acme-challenge/uuid.html")
                if [ "$UUID" == "$UUID_RESULT" ] ; then
                  DOMAINONLINE="true";
                fi
              fi
              [[ ! -z ${DOMAINONLINE} ]] && sleep 3
              TRY=$((TRY+1))
            done
          done
          domain="${domain//,/ }"
          # prevent empty domains
          if [[ ! -z "${domain// }" ]]; then
            dehydrated --cron --domain "$domain"
          fi
        done
      else
        dehydrated --cron --domain "$ACME_DOMAINS"
      fi
    fi
  fi

  echo "-- Moved unused certificate files to the archive directory"
  dehydrated --cleanup

  RESTART_DOCKER="no"

  ## /certs
  if [ -d "/certs" ] ; then
    echo "========== Syncing acme certificates to /certs =========="
    if RSYNC_COMMAND=$(rsync -W -r -p -t -i --copy-links --prune-empty-dirs --delete --delete-excluded --no-compress --exclude=".*" --exclude="cert-*.pem" --exclude="chain-*.pem" --exclude="fullchain-*.pem" --exclude="privkey-*.pem" --exclude="cert-*.csr" "/acme/certs/" "/certs/") ; then
      if [ -n "${RSYNC_COMMAND}" ]; then
        echo "$RSYNC_COMMAND"
        RESTART_DOCKER="yes"
      fi
    fi
  fi

  ## /var/www/vhosts
  if [ -d "/var/www/vhosts" ] ; then
    echo "========== Syncing acme certificates to /var/www/vhosts =========="
    while IFS= read -r -d '' vhost_dir; do

      vhost="${vhost_dir##*/}"
      echo "${vhost_dir} == ${vhost}"

      if [ -f "/acme/certs/${vhost}/privkey.pem" ] && [ -f "/acme/certs/${vhost}/fullchain.pem" ] ; then
        echo " --- privkey.pem | fullchain.pem"
        if RSYNC_COMMAND=$(rsync -W -p -t -i -r --copy-links --no-compress --include="privkey.pem" --include="fullchain.pem" --exclude="*" "/acme/certs/${vhost}/" "/var/www/vhosts/${vhost}/certs/") ; then
          if [ -n "${RSYNC_COMMAND}" ]; then
            echo "$RSYNC_COMMAND"
            RESTART_DOCKER="yes"
          fi
        fi
      fi
      if [ -f "/acme/certs/dhparam.pem" ] ; then
        if RSYNC_COMMAND=$(rsync -W -p -t -i -r --copy-links --no-compress "/acme/certs/dhparam.pem" "/var/www/vhosts/${vhost}/certs/dhparam.pem") ; then
          if [ -n "${RSYNC_COMMAND}" ]; then
            echo "$RSYNC_COMMAND"
            RESTART_DOCKER="yes"
          fi
        fi
      fi
    done < <(find "/var/www/vhosts" -mindepth 1 -maxdepth 1 -type d -print0)  #dirs
  fi

  ## RESTART DOCKER CONTAINERS :: BEGIN
  if [ "$RESTART_DOCKER" == "yes" ] ; then
    if [[ ! -z ${ACME_RESTART_CONTAINERS} ]] && [ -f "/var/run/docker.sock" ] ; then
      echo "========== Restarting Docker Containers =========="
      if [[ $ACME_RESTART_CONTAINERS =~ [\,\;] ]]; then
        container_array=$(echo "$ACME_RESTART_CONTAINERS" | tr ";" "\\n")
        for container in $container_array ; do
          #container="${container//,/ }"
          # prevent empty domains
          if [[ ! -z "${container// }" ]]; then
            if DOCKER_COMMAND=$(docker restart "$container") ; then
              echo "-- Restarted Docker Container: $container"
            else
              echo "Error: Restarting Docker Container"
              echo "$DOCKER_COMMAND"
            fi
          fi
        done
      else
        if DOCKER_COMMAND=$(docker restart "$ACME_RESTART_CONTAINERS") ; then
          echo "-- Restarted Docker Container: $ACME_RESTART_CONTAINERS"
        else
          echo "Error: Restarting Docker Container"
          echo "$DOCKER_COMMAND"
        fi
      fi
    fi
  fi
  ## RESTART DOCKER CONTAINERS :: EMD

  echo "========== SLEEPING for 1 day and watching /acme/domain_list.txt =========="
  if [ ! -f "/acme/domain_list.txt" ] ; then
    touch "/acme/domain_list.txt"
  fi
  inotifywait -e modify --timeout 86400 /acme/domain_list.txt
  sleep 30
else
  echo "========== HTTP NOT online, retry in 1 hour =========="
  sleep 1h
fi
