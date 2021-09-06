#!/usr/bin/env bash
################################################################################
# This is property of eXtremeSHOK.com
# You are free to use, modify and distribute, however you may not remove this notice.
# Copyright (c) Adrian Jon Kriel :: admin@extremeshok.com
################################################################################

# Place a file "/acme/domain_list.txt" with a list of domains
# oe set the env varible "ACME_DOMAINS"
#ACME_DOMAINS="something.com;anotherdomain.com,www.anotherdomain.com"

REGISTERED_EMAIL="admin@extremeshok.com"

# Function to get the IPv4 using an online service
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

if [ -f "/acme/lock" ] ; then
    echo "Removing lock"
    rm -f /acme/lock
fi

if [[ ! "${SKIP_IP_CHECK}" =~ ^([yY][eE][sS]|[yY])+$ ]]; then
    echo "========== Testing IPv4 webserver access =========="
    IPV4=$(xshok_get_ipv4)
    # shellcheck disable=SC2002
    UUID="xshok-$(date +%s)"
    echo "$UUID" > /var/www/.well-known/acme-challenge/uuid.html
    HTTPONLINE="false";
    until [[ ! -z ${HTTPONLINE} ]] || [[ ${TRY} -ge 120 ]]; do
        echo "Testing Localhost"
        if curl --silent "http://127.0.01/" >/dev/null 2>&1 ; then
            echo "Testing IPv4 with UUID: ${IPV4}"      UUID_RESULT=$(curl -L4s "http://${IPV4}/.well-known/acme-challenge/uuid.html")
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
    if [ ! -s "/acme/certs/dhparam.pem" ] ; then
        echo "========== Generating 4096 dhparam =========="
        openssl dhparam -out /acme/certs/dhparam.pem 4096
        echo "Completed"
    elif ! grep -q "BEGIN DH PARAMETERS" /certs/dhparam.pem || ! grep -q "END DH PARAMETERS" /certs/dhparam.pem ; then
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

if [[ ! -z ${HTTPONLINE} ]]  ; then
    ## UPDATE
    echo "========== UPDATE ACME.SH =========="
    cd /usr/local/src/acme.sh || exit
    git pull --depth=1

    ## DEHYDRATED
    echo "========== ACME.SH RUNNING =========="
    #dehydrated --register --accept-terms
    acme.sh --register-account --cert-home "/acme/certs" --config-home "/acme" --webroot "/var/www" -m "$REGISTERED_EMAIL"

    ## exists and is not empty
    # if [ -s "/acme/domain_list.txt" ] ; then
    #     echo "-- Sign/renew new/changed/expiring certificates from /acme/domain_list.txt"
    #     dehydrated --cron --ipv4
    # else
        # remove "'`
        ACME_DOMAINS="${ACME_DOMAINS//\"/}"
        ACME_DOMAINS="${ACME_DOMAINS//\'/}"
        ACME_DOMAINS="${ACME_DOMAINS//\`/}"
        if [[ ! -z $ACME_DOMAINS ]]; then
            echo "-- Sign/renew new/changed/expiring certificates"
            if [[ $ACME_DOMAINS =~ [\,\;] ]]; then
                domain_array=$(echo "$ACME_DOMAINS" | tr ";" "\\n")
                for domain in $domain_array ; do
                    #check the domains can be accessed, prevents wasted acme calls which will fail
                    domain_micro_array=$(echo "$domain" | tr "," "\\n")
                    for domain_micro in $domain_micro_array ; do
                        UUID="xshok-$(date +%s)"
                        echo "$UUID" > /var/www/.well-known/acme-challenge/uuid.html
                        DOMAINONLINE="false"
                        until [[ ! -z ${DOMAINONLINE} ]] || [[ ${TRY} -ge 120 ]]; do
                            echo "Testing Localhost"
                            if curl --silent "http://127.0.0.1/" >/dev/null 2>&1 ; then
                                echo "Testing Domain with UUID: ${domain_micro}"
                                UUID_RESULT=$(curl -L4s "http://${domain_micro}/.well-known/acme-challenge/uuid.html")
                                if [ "$UUID" == "$UUID_RESULT" ] ; then
                                    DOMAINONLINE="true";
                                    echo "Domain and uuid: valid"
                                fi
                            fi
                            [[ ! -z ${DOMAINONLINE} ]] && sleep 3
                            TRY=$((TRY+1))
                        done
                    done
                    domain="${domain//,/ }"
                    # prevent empty domains
                    if [[ ! -z "${domain// }" ]]; then
                        #dehydrated --cron --ipv4 --domain "$domain"
                        acme.sh --issue --staging --cert-home "/acme/certs" --config-home "/acme" --webroot "/var/www" -d "$domain"
                    fi
                done
            else
                #dehydrated --cron --ipv4 --domain "$ACME_DOMAINS"
                acme.sh --issue --staging --cert-home "/acme/certs" --config-home "/acme" --webroot "/var/www" -d "$ACME_DOMAINS"
            fi
        fi
    #fi

    # echo "-- Moved unused certificate files to the archive directory"
    # dehydrated --cleanup

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
