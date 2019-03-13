#!/bin/bash

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

  if [ -f "$KEYFILE" ] ; then
    certdir="${CERTFILE/\/cert.pem/}"
    if [ -f "$FULLCHAINFILE" ] ; then
      echo "Generating fullchainprivkey.pem for ${DOMAIN} @ ${TIMESTAMP}"
      cat "$FULLCHAINFILE" "$KEYFILE" > "${certdir}/fullchainprivkey.pem"
    fi
    if [ -f "$CERTFILE" ] ; then
      echo "Generating certprivkey.pem for ${DOMAIN} @ ${TIMESTAMP}"
      cat "$CERTFILE" "$KEYFILE" > "${certdir}/certprivkey.pem"
    fi
    echo "Generated ${certdir}/fullchainprivkey.pem @ ${TIMESTAMP}"
  fi
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
  #TODAYS_DATE="${2}" SENDER="${3}" RECIPIENT="${4}"
  email_to="${NOTIFY}"
  email_from="${SMTP_USER:-"admin@$(hostname -f)"}"
  if [[ $NOTIFY =~ [@] ]]; then
    if [ -f "/etc/msmtprc" ] ; then
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
    if [ -f "/etc/msmtprc" ] ; then
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

send_notification() {
  local DOMAIN="${1}"
  #TODAYS_DATE="${2}" SENDER="${3}" RECIPIENT="${4}"
  email_to="${NOTIFY}"
  email_from="${SMTP_USER:-"admin@$(hostname -f)"}"
  if [[ $NOTIFY =~ [@] ]]; then
    if [ -f "/etc/msmtprc" ] ; then
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

exit_hook() {
  # This hook is called at the end of a dehydrated command and can be used
  # to do some final (cleanup or other) tasks.
  cd "$SCRIPTDIR" || exit 1
}

### Initialise handlers
HANDLER="$1"; shift
#if [[ "${HANDLER}" =~ ^(deploy_challenge|clean_challenge|deploy_cert|unchanged_cert|invalid_challenge|request_failure|send_notification|exit_hook)$ ]]; then
#if [[ "${HANDLER}" =~ ^(deploy_challenge|clean_challenge|send_notification|exit_hook)$ ]]; then
if [[ "${HANDLER}" =~ ^(deploy_cert|send_notification|exit_hook)$ ]]; then
  "$HANDLER" "$@"
fi
