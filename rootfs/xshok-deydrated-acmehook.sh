#!/usr/bin/env bash
################################################################################
# This is property of eXtremeSHOK.com
# You are free to use, modify and distribute, however you may not remove this notice.
# Copyright (c) Adrian Jon Kriel :: admin@extremeshok.com
################################################################################

SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SOURCE" ]; do # resolve $SOURCE until the file is no longer a symlink
    SCRIPTDIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
    SOURCE="$(readlink "$SOURCE")"
    [[ $SOURCE != /* ]] && SOURCE="$SCRIPTDIR/$SOURCE" # if $SOURCE was a relative symlink, we need to resolve it relative to the path where the symlink file was located
done
SCRIPTDIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"

# ################################################################################

# ######  #######    #     # ####### #######    ####### ######  ### #######
# #     # #     #    ##    # #     #    #       #       #     #  #     #
# #     # #     #    # #   # #     #    #       #       #     #  #     #
# #     # #     #    #  #  # #     #    #       #####   #     #  #     #
# #     # #     #    #   # # #     #    #       #       #     #  #     #
# #     # #     #    #    ## #     #    #       #       #     #  #     #
# ######  #######    #     # #######    #       ####### ######  ###    #
#
# ################################################################################

deploy_challenge() {
    local DOMAIN="${1}" TOKEN_FILENAME="${2}" TOKEN_VALUE="${3}"

    # This hook is called once for every domain that needs to be
    # validated, including any alternative names you may have listed.
    #
    # Parameters:
    # - DOMAIN
    #   The domain name (CN or subject alternative name) being
    #   validated.
    # - TOKEN_FILENAME
    #   The name of the file containing the token to be served for HTTP
    #   validation. Should be served by your web server as
    #   /.well-known/acme-challenge/${TOKEN_FILENAME}.
    # - TOKEN_VALUE
    #   The token value that needs to be served for validation. For DNS
    #   validation, this is what you want to put in the _acme-challenge
    #   TXT record. For HTTP validation it is the value that is expected
    #   be found in the $TOKEN_FILENAME file.

    # Simple example: Use nsupdate with local named
    # printf 'server 127.0.0.1\nupdate add _acme-challenge.%s 300 IN TXT "%s"\nsend\n' "${DOMAIN}" "${TOKEN_VALUE}" | nsupdate -k /var/run/named/session.key
}

clean_challenge() {
    local DOMAIN="${1}" TOKEN_FILENAME="${2}" TOKEN_VALUE="${3}"

    # This hook is called after attempting to validate each domain,
    # whether or not validation was successful. Here you can delete
    # files or DNS records that are no longer needed.
    #
    # The parameters are the same as for deploy_challenge.

    # Simple example: Use nsupdate with local named
    # printf 'server 127.0.0.1\nupdate delete _acme-challenge.%s TXT "%s"\nsend\n' "${DOMAIN}" "${TOKEN_VALUE}" | nsupdate -k /var/run/named/session.key
}

sync_cert() {
    local KEYFILE="${1}" CERTFILE="${2}" FULLCHAINFILE="${3}" CHAINFILE="${4}" REQUESTFILE="${5}"

    # This hook is called after the certificates have been created but before
    # they are symlinked. This allows you to sync the files to disk to prevent
    # creating a symlink to empty files on unexpected system crashes.
    #
    # This hook is not intended to be used for further processing of certificate
    # files, see deploy_cert for that.
    #
    # Parameters:
    # - KEYFILE
    #   The path of the file containing the private key.
    # - CERTFILE
    #   The path of the file containing the signed certificate.
    # - FULLCHAINFILE
    #   The path of the file containing the full certificate chain.
    # - CHAINFILE
    #   The path of the file containing the intermediate certificate(s).
    # - REQUESTFILE
    #   The path of the file containing the certificate signing request.

    # Simple example: sync the files before symlinking them
    # sync "${KEYFILE}" "${CERTFILE} "${FULLCHAINFILE}" "${CHAINFILE}" "${REQUESTFILE}"
}

deploy_cert() {
    local DOMAIN="${1}" KEYFILE="${2}" CERTFILE="${3}" FULLCHAINFILE="${4}" CHAINFILE="${5}" TIMESTAMP="${6}"

    # This hook is called once for each certificate that has been
    # produced. Here you might, for instance, copy your new certificates
    # to service-specific locations and reload the service.
    #
    # Parameters:
    # - DOMAIN
    #   The primary domain name, i.e. the certificate common
    #   name (CN).
    # - KEYFILE
    #   The path of the file containing the private key.
    # - CERTFILE
    #   The path of the file containing the signed certificate.
    # - FULLCHAINFILE
    #   The path of the file containing the full certificate chain.
    # - CHAINFILE
    #   The path of the file containing the intermediate certificate(s).
    # - TIMESTAMP
    #   Timestamp when the specified certificate was created.

    #domainname="${rootlevel##*/}"

    if [ -s "$KEYFILE" ] ; then
        certdir="${CERTFILE/\/cert.pem/}"
        if [ -s "$FULLCHAINFILE" ] ; then
            echo "Generating fullchainprivkey.pem for ${DOMAIN} @ ${TIMESTAMP}"
            cat "$FULLCHAINFILE" "$KEYFILE" > "${certdir}/fullchainprivkey.pem"
        fi
        if [ -s "$CERTFILE" ] ; then
            echo "Generating certprivkey.pem for ${DOMAIN} @ ${TIMESTAMP}"
            cat "$CERTFILE" "$KEYFILE" > "${certdir}/certprivkey.pem"
        fi
        echo "Generated ${certdir}/fullchainprivkey.pem @ ${TIMESTAMP}"
    fi
}

deploy_ocsp() {
    local DOMAIN="${1}" OCSPFILE="${2}" TIMESTAMP="${3}"

    # This hook is called once for each updated ocsp stapling file that has
    # been produced. Here you might, for instance, copy your new ocsp stapling
    # files to service-specific locations and reload the service.
    #
    # Parameters:
    # - DOMAIN
    #   The primary domain name, i.e. the certificate common
    #   name (CN).
    # - OCSPFILE
    #   The path of the ocsp stapling file
    # - TIMESTAMP
    #   Timestamp when the specified ocsp stapling file was created.

    # Simple example: Copy file to nginx config
    # cp "${OCSPFILE}" /etc/nginx/ssl/; chown -R nginx: /etc/nginx/ssl
    # systemctl reload nginx
}

unchanged_cert() {
    local DOMAIN="${1}" KEYFILE="${2}" CERTFILE="${3}" FULLCHAINFILE="${4}" CHAINFILE="${5}"

    # This hook is called once for each certificate that is still
    # valid and therefore wasn't reissued.
    #
    # Parameters:
    # - DOMAIN
    #   The primary domain name, i.e. the certificate common
    #   name (CN).
    # - KEYFILE
    #   The path of the file containing the private key.
    # - CERTFILE
    #   The path of the file containing the signed certificate.
    # - FULLCHAINFILE
    #   The path of the file containing the full certificate chain.
    # - CHAINFILE
    #   The path of the file containing the intermediate certificate(s).

}

invalid_challenge() {
    local DOMAIN="${1}" RESPONSE="${2}"
    # This hook is called if the challenge response has failed, so domain
    # owners can be aware and act accordingly.
    #
    # Parameters:
    # - DOMAIN
    #   The primary domain name, i.e. the certificate common
    #   name (CN).
    # - RESPONSE
    #   The response that the verification server returned
    email_to="${NOTIFY}"
    email_from="${SMTP_USER:-"admin@$(hostname -f)"}"
    if [[ $NOTIFY =~ [@] ]]; then
        if [ -s "/etc/msmtprc" ] ; then
            echo "Using Remote SMTP"
            sendmail_app="msmtp --read-envelope-from --read-recipients --remove-bcc-headers=off -d"
        elif [ "$(command -v sendmail)" != "" ] ; then
            echo "Using sendmail"
            sendmail_app="sendmail -t" #-t set options from header
        fi
        echo "Sending Email to: ${email_to}"
        {
            #Email headerquota
            echo "From: ${email_to}"
            echo "To: ${email_from}"
            echo "Subject: eXtremeSHOK.com :: Certificate Failure :: ${DOMAIN}"
            echo "Content-Type: text/plain; charset=\"UTF-8\""
            echo "" #must be a blank line
            echo "This email was automatically sent by the acme server."
            echo ""
            echo "A certificate request failure for the domain: ${DOMAIN}"
            echo ""
            echo "${RESPONSE}"
            echo ""
            echo "Please confirm certificate is working as expected."
        } | $sendmail_app
    fi
}

request_failure() {
    local STATUSCODE="${1}" REASON="${2}" REQTYPE="${3}"
    # response code that does not start with '2'. Useful to alert admins
    # about problems with requests.
    #
    # Parameters:
    # - STATUSCODE
    #   The HTML status code that originated the error.
    # - REASON
    #   The specified reason for the error.
    # - REQTYPE
    #   The kind of request that was made (GET, POST...)
    email_to="${NOTIFY}"
    email_from="${SMTP_USER:-"admin@$(hostname -f)"}"
    if [[ $NOTIFY =~ [@] ]]; then
        if [ -s "/etc/msmtprc" ] ; then
            echo "Using Remote SMTP"
            sendmail_app="msmtp --read-envelope-from --read-recipients --remove-bcc-headers=off -d"
        elif [ "$(command -v sendmail)" != "" ] ; then
            echo "Using sendmail"
            sendmail_app="sendmail -t" #-t set options from header
        fi
        echo "Sending Email to: ${email_to}"
        {
            #Email headerquota
            echo "From: ${email_to}"
            echo "To: ${email_from}"
            echo "Subject: eXtremeSHOK.com :: Certificate Request Failure"
            echo "Content-Type: text/plain; charset=\"UTF-8\""
            echo "" #must be a blank line
            echo "This email was automatically sent by the acme server."
            echo ""
            echo "Status code: ${STATUSCODE} | Request Type: ${REQTYPE}"
            echo "${REASON}"
            echo ""
            echo "Please confirm certificate is working as expected."
        } | $sendmail_app
    fi
}

generate_csr() {
    local DOMAIN="${1}" CERTDIR="${2}" ALTNAMES="${3}"

    # This hook is called before any certificate signing operation takes place.
    # It can be used to generate or fetch a certificate signing request with external
    # tools.
    # The output should be just the cerificate signing request formatted as PEM.
    #
    # Parameters:
    # - DOMAIN
    #   The primary domain as specified in domains.txt. This does not need to
    #   match with the domains in the CSR, it's basically just the directory name.
    # - CERTDIR
    #   Certificate output directory for this particular certificate. Can be used
    #   for storing additional files.
    # - ALTNAMES
    #   All domain names for the current certificate as specified in domains.txt.
    #   Again, this doesn't need to match with the CSR, it's just there for convenience.

    # Simple example: Look for pre-generated CSRs
    # if [ -e "${CERTDIR}/pre-generated.csr" ]; then
    #   cat "${CERTDIR}/pre-generated.csr"
    # fi
}

send_notification() {
    local DOMAIN="${1}"
    #TODAYS_DATE="${2}" SENDER="${3}" RECIPIENT="${4}"
    email_to="${NOTIFY}"
    email_from="${SMTP_USER:-"admin@$(hostname -f)"}"
    if [[ $NOTIFY =~ [@] ]]; then
        if [ -s "/etc/msmtprc" ] ; then
            echo "Using Remote SMTP"
            sendmail_app="msmtp --read-envelope-from --read-recipients --remove-bcc-headers=off -d"
        elif [ "$(command -v sendmail)" != "" ] ; then
            echo "Using sendmail"
            sendmail_app="sendmail -t" #-t set options from header
        fi
        echo "Sending Email to: ${email_to}"
        {
            #Email headerquota
            echo "From: ${email_to}"
            echo "To: ${email_from}"
            echo "Subject: eXtremeSHOK.com :: New Certificate Deployed :: ${DOMAIN}"
            echo "Content-Type: text/plain; charset=\"UTF-8\""
            echo "" #must be a blank line
            echo "This email was automatically sent by the acme server."
            echo ""
            echo "A new certificate has been deployed for the domain: ${DOMAIN}"
            echo ""
            echo "Please confirm certificate is working as expected."
        } | $sendmail_app
    fi
}

startup_hook() {
    # This hook is called before the cron command to do some initial tasks
    # (e.g. starting a webserver).

    :
}

exit_hook() {
    local ERROR="${1:-}"
    # This hook is called at the end of the cron command and can be used to
    # do some final (cleanup or other) tasks.
    #
    # Parameters:
    # - ERROR
    #   Contains error message if dehydrated exits with error

    cd "$SCRIPTDIR" || exit 1
}

### Initialise handlers
HANDLER="$1"; shift
#if [[ "${HANDLER}" =~ ^(deploy_challenge|clean_challenge|sync_cert|deploy_cert|deploy_ocsp|unchanged_cert|invalid_challenge|request_failure|generate_csr|startup_hook|exit_hook)$ ]]; then
#if [[ "${HANDLER}" =~ ^(deploy_challenge|clean_challenge|deploy_cert|unchanged_cert|invalid_challenge|request_failure|send_notification|exit_hook)$ ]]; then
#if [[ "${HANDLER}" =~ ^(deploy_challenge|clean_challenge|send_notification|exit_hook)$ ]]; then
if [[ "${HANDLER}" =~ ^(deploy_cert|send_notification|exit_hook)$ ]]; then
    "$HANDLER" "$@"
fi
