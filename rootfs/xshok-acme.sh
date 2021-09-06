#!/usr/bin/env bash
################################################################################
# This is property of eXtremeSHOK.com
# You are free to use, modify and distribute, however you may not remove this notice.
# Copyright (c) Adrian Jon Kriel :: admin@extremeshok.com
################################################################################
# Version 2
# using acme.sh
################################################################################

# Place a file "/acme/domain_list.txt" with a list of domains
# or set the env varible "ACME_DOMAINS"
#ACME_DOMAINS="something.com;anotherdomain.com,www.anotherdomain.com"

## enable case insensitve matching
shopt -s nocaseglob

######################### VARIABLES

XS_REGISTERED_EMAIL="${REGISTERED_EMAIL:-admin@extremeshok.com}"
XS_DEFAULT_CA="${DEFAULT_CA:-letsencrypt}"
XS_ENABLE_STAGING="${ENABLE_STAGING:-no}"
XS_ENABLE_DEBUG="${ENABLE_DEBUG:-no}"
XS_SKIP_IP_CHECK="${SKIP_IP_CHECK:-no}"
XS_SKIP_DOMAIN_CHECK="${SKIP_DOMAIN_CHECK:-no}"
XS_GENERATE_DHPARAM="${GENERATE_DHPARAM:-yes}"
XS_UPDATE_ACME="${UPDATE_ACME:-yes}"
XS_RESTART_DOCKER="${RESTART_DOCKER:-no}"
XS_RESTART_DOCKER_CONTAINERS="${ACME_RESTART_CONTAINERS:-}"


if [ "${XS_ENABLE_STAGING,,}" == "yes" ] || [ "${XS_ENABLE_STAGING,,}" == "true" ] || [ "${XS_ENABLE_STAGING,,}" == "on" ] || [ "${XS_ENABLE_STAGING}" == "1" ] ; then
    XS_ENABLE_STAGING="--staging"
else
    XS_ENABLE_STAGING=""
fi
if [ "${XS_ENABLE_DEBUG,,}" == "yes" ] || [ "${XS_ENABLE_DEBUG,,}" == "true" ] || [ "${XS_ENABLE_DEBUG,,}" == "on" ] || [ "${XS_ENABLE_DEBUG}" == "1" ] ; then
    XS_ENABLE_DEBUG="--debug "
else
    XS_ENABLE_DEBUG=""
fi

#Generate a fresh UUID
UUID="xshok-$(date +%s)"
echo "$UUID" > /var/www/.well-known/acme-challenge/uuid.html

######################### FUNCTIONS

# Function to get the IPv4 using an online service
#returns the IP
function xshok_get_ipv4 () {
    local IPV4=""
    local IPV4_SRCS=("v4.ident.me" "ifconfig.co")
    local TRY=""
    until [[ ! -z ${IPV4} ]] || [[ ${TRY} -ge 30 ]]; do
        local IPV4_SRC="${IPV4_SRCS[$RANDOM%${#IPV4_SRCS[@]}]}"
        if [ ! -z "$(which curl 2> /dev/null)" ] ; then
            IPV4="$(curl --connect-timeout 15 -m 15 -L4s "${IPV4_SRC}" 2> /dev/null | grep -E "^((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$" | tr -d '\n' | tr -d '\r' | xargs)"
        else
            IPV4="$(wget -qO- --connect-timeout=15 --read-timeout=15 -4 "${IPV4_SRC}" 2> /dev/null | grep -E "^((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$" | tr -d '\n' | tr -d '\r' | xargs)"
        fi
        if [[ ! $IPV4 =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]] ; then
            #invalid IP returned, try again
            IPV4=""
        fi
        [[ ! -z ${TRY} ]] && sleep 1
        TRY=$((TRY+1))
    done
    echo "${IPV4}"
}

# Function to verify the domain is rechable and pointing to this server, prevents wasted acme runs
#returns 0 (online) or 1 (offline)
function xshok_verify_domain () { #domain
    DOMAIN_NAME="$1"
    if [ "${XS_SKIP_DOMAIN_CHECK,,}" == "yes" ] || [ "${XS_SKIP_DOMAIN_CHECK,,}" == "true" ] || [ "${XS_SKIP_DOMAIN_CHECK,,}" == "on" ] || [ "${XS_SKIP_DOMAIN_CHECK}" == "1" ] ; then
        DOMAINONLINE="true"
    else
        DOMAINONLINE=""
        TRY=0
        until [[ ! -z ${DOMAINONLINE} ]] || [[ ${TRY} -ge 30 ]]; do
            # Testing Localhost
            if curl --silent "http://127.0.0.1/" >/dev/null 2>&1 ; then
                # Testing DOMAIN_NAME
                UUID_RESULT=$(curl -L4s "http://${DOMAIN_NAME}/.well-known/acme-challenge/uuid.html")
                if [ "$UUID" == "$UUID_RESULT" ] ; then
                    # domain online
                    DOMAINONLINE="true"
                fi
            fi
            [[ -z ${DOMAINONLINE} ]] && sleep 3
            TRY=$((TRY+1))
        done
    fi
    if [ "$DOMAINONLINE" == "true" ] ; then
      #domain online
      return 1
    else
      #domain offline
      return 0
    fi
}

######################### MAIN

## Generate DHPARAM
if [ "${XS_GENERATE_DHPARAM,,}" == "yes" ] || [ "${XS_GENERATE_DHPARAM,,}" == "true" ] || [ "${XS_GENERATE_DHPARAM,,}" == "on" ] || [ "${XS_GENERATE_DHPARAM}" == "1" ] ; then
    if [ ! -s "/acme/certs/dhparam.pem" ] ; then
        echo "========== Generating 4096 dhparam =========="
        openssl dhparam -out /acme/certs/dhparam.pem 4096
        echo "Completed"
    elif ! grep -q "BEGIN DH PARAMETERS" /acme/certs/dhparam.pem || ! grep -q "END DH PARAMETERS" /acme/certs/dhparam.pem ; then
        echo "========== Generating New 4096 dhparam =========="
        rm -f /acme/certs/dhparam.pem
        openssl dhparam -out /acme/certs/dhparam.pem 4096
        echo "Completed"
    fi
elif [ ! -s "/acme/certs/dhparam.pem" ] ; then
    echo "========== Using bundled 4096 dhparam =========="
    cp "/etc/xshok/dhparam.pem" "/acme/certs/dhparam.pem"
    chmod 600 "/acme/certs/dhparam.pem"
fi

## Test IPV4 is accessible
if [ "${XS_SKIP_IP_CHECK,,}" != "yes" ] && [ "${XS_SKIP_IP_CHECK,,}" != "true" ] && [ "${XS_SKIP_IP_CHECK,,}" != "on" ] && [ "${XS_SKIP_IP_CHECK}" != "1" ] ; then
    echo "========== Testing IPv4 webserver access =========="
    IPV4="$(xshok_get_ipv4)"
    # shellcheck disable=SC2002
    if xshok_verify_domain "$IPV4" ; then
        echo "========== IPv4 (${IPV4}) NOT online, sleeping for 1 hour =========="
        sleep 1h
        exit
    else
        echo "========== IPv4 (${IPV4}) online =========="
    fi
fi

## UPDATE ACME.SH from github
if [ "${XS_UPDATE_ACME,,}" == "yes" ] || [ "${XS_UPDATE_ACME,,}" == "true" ] || [ "${XS_UPDATE_ACME,,}" == "on" ] || [ "${XS_UPDATE_ACME}" == "1" ] ; then
    echo "========== Updating ACME.SH =========="
    cd /usr/local/src/acme.sh || exit
    git pull --depth=1
fi

## ACME INITIALISATION
echo "========== ACME.SH Initialising =========="
#dehydrated --register --accept-terms
acme.sh --register-account --cert-home "/acme/certs" --config-home "/acme" --webroot "/var/www" -m "$XS_REGISTERED_EMAIL"
acme.sh --cert-home "/acme/certs" --config-home "/acme" --webroot "/var/www" --set-default-ca --server "$XS_DEFAULT_CA"

# exists and is not empty
if [ -s "/acme/domain_list.txt" ] ; then
    echo "-- Sign/renew new/changed/expiring certificates from /acme/domain_list.txt"
    #dehydrated --cron --ipv4

    while read line; do
        # reading each line
        echo "$line"
        readarray -d " " -t strarr <<< "$line"
        parent_domain="${line// */}"

        if xshok_verify_domain "$parent_domain" ; then
          echo "Parent: ${parent_domain} could not be verified, skipping"
        else
            echo "Parent: ${parent_domain}"
            add_domain=""
            for (( n=1; n < ${#strarr[*]}; n++)) ; do  #skip the first 
                alias_domain="${strarr[n]}"
                if [ "${parent_domain}" == "$alias_domain" ] ; then
                  echo "Alias: ${parent_domain} and  parent: ${alias_domain} are the same, skipping"
                else
                    if xshok_verify_domain "$alias_domain" ; then
                      echo "Alias: ${alias_domain} for parent: ${parent_domain} could not be verified, skipping"
                    else
                      echo "Alias: ${alias_domain} for parent: ${parent_domain} , added"
                      add_domain="-d ${alias_domain} ${add_domain}"
                    fi

                fi
            done
            acme.sh --issue $XS_ENABLE_STAGING $XS_ENABLE_DEBUG --cert-home "/acme/certs" --config-home "/acme" --webroot "/var/www" \
                --cert-file "/acme/certs/${parent_domain}/cert.pem" --ca-file "/acme/certs/${parent_domain}/chain.pem" \
                --fullchain-file "/acme/certs/${parent_domain}/fullchain.pem" --key-file "/acme/certs/${parent_domain}/privkey.pem" \
                -d "${parent_domain}" $add_domain
        fi

    done < "/acme/domain_list.txt"

    # --deploy-hook <hookname>          The hook file to deploy cert
else
    echo "disabled ACME_DOMAINS support, will be fixed shortly"
    # # remove "'`
    # ACME_DOMAINS="${ACME_DOMAINS//\"/}"
    # ACME_DOMAINS="${ACME_DOMAINS//\'/}"
    # ACME_DOMAINS="${ACME_DOMAINS//\`/}"
    # if [[ ! -z $ACME_DOMAINS ]]; then
    #     echo "-- Sign/renew new/changed/expiring certificates"
    #     if [[ $ACME_DOMAINS =~ [\,\;] ]]; then
    #         domain_array=$(echo "$ACME_DOMAINS" | tr ";" "\\n")
    #         for domain in $domain_array ; do
    #             #check the domains can be accessed, prevents wasted acme calls which will fail
    #             domain_micro_array=$(echo "$domain" | tr "," "\\n")
    #             for domain_micro in $domain_micro_array ; do
    #                 UUID="xshok-$(date +%s)"
    #                 echo "$UUID" > /var/www/.well-known/acme-challenge/uuid.html
    #                 DOMAINONLINE="false"
    #                 until [[ ! -z ${DOMAINONLINE} ]] || [[ ${TRY} -ge 120 ]]; do
    #                     echo "Testing Localhost"
    #                     if curl --silent "http://127.0.0.1/" >/dev/null 2>&1 ; then
    #                         echo "Testing Domain with UUID: ${domain_micro}"
    #                         UUID_RESULT=$(curl -L4s "http://${domain_micro}/.well-known/acme-challenge/uuid.html")
    #                         if [ "$UUID" == "$UUID_RESULT" ] ; then
    #                             DOMAINONLINE="true";
    #                             echo "Domain and uuid: valid"
    #                         fi
    #                     fi
    #                     [[ ! -z ${DOMAINONLINE} ]] && sleep 3
    #                     TRY=$((TRY+1))
    #                 done
    #             done
    #             domain="${domain//,/ }"
    #             # prevent empty domains
    #             if [[ ! -z "${domain// }" ]]; then
    #                 #dehydrated --cron --ipv4 --domain "$domain"
    #                 acme.sh --issue $XS_ENABLE_STAGING $XS_ENABLE_DEBUG --cert-home "/acme/certs" --config-home "/acme" --webroot "/var/www" \
        #                     --cert-file "/acme/certs/${domain}/cert.pem" --ca-file "/acme/certs/${domain}/chain.pem" \
        #                     --fullchain-file "/acme/certs/${domain}/fullchain.pem" --key-file "/acme/certs/${domain}/privkey.pem" \
        #                     -d "${domain}"
    #             fi
    #         done
    #     else
    #         #dehydrated --cron --ipv4 --domain "$ACME_DOMAINS"
    #         acme.sh --issue $XS_ENABLE_STAGING $XS_ENABLE_DEBUG --cert-home "/acme/certs" --config-home "/acme" --webroot "/var/www" \
        #             --cert-file "/acme/certs/${ACME_DOMAINS}/cert.pem" --ca-file "/acme/certs/${ACME_DOMAINS}/chain.pem" \
        #             --fullchain-file "/acme/certs/${ACME_DOMAINS}/fullchain.pem" --key-file "/acme/certs/${ACME_DOMAINS}/privkey.pem" \
        #             -d "${ACME_DOMAINS}"
    #     fi
    # fi
fi

RESTART_DOCKER="no"

## sync to /certs
if [ -d "/certs" ] ; then
    echo "========== Syncing acme certificates to /certs =========="
    if RSYNC_COMMAND=$(rsync -W -r -p -t -i --copy-links --prune-empty-dirs --delete --delete-excluded --no-compress --exclude=".*" --exclude="cert-*.pem" --exclude="chain-*.pem" --exclude="fullchain-*.pem" --exclude="privkey-*.pem" --exclude="cert-*.csr" "/acme/certs/" "/certs/") ; then
        if [ -n "${RSYNC_COMMAND}" ]; then
            echo "$RSYNC_COMMAND"
            RESTART_DOCKER="yes"
        fi
    fi
fi

## sync to /var/www/vhosts
if [ -d "/var/www/vhosts" ] ; then
    echo "========== Syncing acme certificates to /var/www/vhosts =========="
    while IFS= read -r -d '' vhost_dir; do
        vhost="${vhost_dir##*/}"
        #echo "${vhost_dir} == ${vhost}"
        if [ -s "/acme/certs/${vhost}/privkey.pem" ] && [ -s "/acme/certs/${vhost}/fullchain.pem" ] ; then
            if RSYNC_COMMAND=$(rsync -W -p -t -i -r --copy-links --no-compress --include="privkey.pem" --include="fullchain.pem" --exclude="*" "/acme/certs/${vhost}/" "/var/www/vhosts/${vhost}/certs/") ; then
                if [ -n "${RSYNC_COMMAND}" ]; then
                    echo "$RSYNC_COMMAND"
                    RESTART_DOCKER="yes"
                fi
            fi
        fi
        if [ -s "/acme/certs/dhparam.pem" ] ; then
            if RSYNC_COMMAND=$(rsync -W -p -t -i -r --copy-links --no-compress "/acme/certs/dhparam.pem" "/var/www/vhosts/${vhost}/certs/dhparam.pem") ; then
                if [ -n "${RSYNC_COMMAND}" ]; then
                    echo "$RSYNC_COMMAND"
                    RESTART_DOCKER="yes"
                fi
            fi
        fi
    done < <(find "/var/www/vhosts" -mindepth 1 -maxdepth 1 -type d -print0)  #dirs
fi

## restart docker containers if required
if [ "${XS_RESTART_DOCKER,,}" == "yes" ] || [ "${XS_RESTART_DOCKER,,}" == "true" ] || [ "${XS_RESTART_DOCKER,,}" == "on" ] || [ "${XS_RESTART_DOCKER}" == "1" ] ; then
    if [ "$RESTART_DOCKER" == "yes" ] ; then
        if [[ ! -z ${XS_RESTART_DOCKER_CONTAINERS} ]] && [ -f "/var/run/docker.sock" ] ; then
            echo "========== Restarting Docker Containers =========="
            if [[ $XS_RESTART_DOCKER_CONTAINERS =~ [\,\;] ]]; then
                container_array=$(echo "$XS_RESTART_DOCKER_CONTAINERS" | tr ";" "\\n")
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
                if DOCKER_COMMAND=$(docker restart "$XS_RESTART_DOCKER_CONTAINERS") ; then
                    echo "-- Restarted Docker Container: $XS_RESTART_DOCKER_CONTAINERS"
                else
                    echo "Error: Restarting Docker Container"
                    echo "$DOCKER_COMMAND"
                fi
            fi
        fi
    fi
fi

echo "========== SLEEPING for 1 day and watching /acme/domain_list.txt =========="
if [ ! -f "/acme/domain_list.txt" ] ; then
    touch "/acme/domain_list.txt"
fi
inotifywait -e modify --timeout 86400 /acme/domain_list.txt
sleep 30
