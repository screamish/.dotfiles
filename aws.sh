#!/bin/bash
# bash functions to autenticate and assume roles in aws federated accounts
# required tools on $PATH - aws, date, curl, jq, libxml2-utils

# requried environment variables:
export AWS_CLI=`which aws`

# optional environment variable, to automatically assume a specific role when calling assume()
# AWS_ASSUME_ROLE=arn:aws:iam::369407384105:role/cross-account-federated-role

aws_saml() {
  credentials
  $AWS_CLI $@
}

credentials() {
  check_expired
  if [ -z $EXPIRE ]; then
    echo "new credentials required"
    authenticate
  fi
}

check_expired() {
  local now=$( date -u +%s )
  local remain=$(( EXPIRE - now ))
  if [ -n "$EXPIRETIME" ] && [ $remain -lt 0 ]; then
    echo "aws session has expired, unsetting creds and expire"
    aws_logout
  else
    if [ -n "$AWS_DEBUG" ]; then
        echo "$remain seconds remain for credential expiration"
    fi
  fi
}

authenticate() {
  if ! saml_auth; then
    echo "Cannot authenticate"
    return 1
  fi

  local principal=""
  local role=""
  local assertion=""
  local saml_auth_result=""
  #Certain linux distros may been `base64 -d`
  extract_asserted_roles  $( echo -e "$SAML_RESPONSE" | base64 -D | xmllint --format - )

  select_saml_role
  read saml_auth_role

  if [[ ${AWS_ROLES[$saml_auth_role]} =~ (arn.[^,]*),(arn.*[^\[]) ]]; then
    principal=${BASH_REMATCH[1]}
    role=${BASH_REMATCH[2]}
  else
    echo "Roles did not match expected pattern"
    return 1
  fi
  echo "authenticating for account $principal and role $role"
  if [ -n "$SAML_RESPONSE" ]; then
    assertion=$( echo -e "$SAML_RESPONSE" )
    saml_auth_result=$( $AWS_CLI sts assume-role-with-saml \
      --role-arn $role \
      --principal-arn $principal \
      --duration-seconds 3600 \
      --saml-assertion "$assertion" )
    if [ $? = 0 ]; then
      extract_creds $( echo "$saml_auth_result" )
    else
        echo "Error assuming role"
        return 1
    fi
  else
    echo "No SAML response received"
    return 1
  fi
}

saml_auth() {
  if ! type -P curl >/dev/null; then
    echo "You must have either curl installed, and in your \$PATH"
    return 1
  fi

  if ! type -P uuidgen >/dev/null; then
    echo "You must have uuidgen installed ..."
    return 1
  fi

  echo "logging in to saml provider to obtain saml assertion."
  local default_user=$USER
  local username=""
  local userid=""
  if [ -n "$AWS_USER" ]; then
    default_user=$AWS_USER
  fi
  echo -n "Username [$default_user]:  "
  read username
  if [ -z $username ]; then
    userid=$default_user
  else
    userid=$username
  fi

  # password = the user's password
  read -s -p "Password: " userpw
  echo ""

  # idphost = your idp hostname
  local IDP_HOST="fs.seek.com.au"

  if [ -n "$IDP_HOST" ]; then
    default_idphost=$IDP_HOST
    echo "authenticating to : $IDP_HOST"
  else
    echo -n "idp host [$default_idphost]: "
    read host
  fi

  if [ -z $host ]; then
    idphost=$default_idphost
  else
    idphost=$host
  fi

  # rpid = a valid SP entityId that is configured for ECP
  local rpid="urn:amazon:webservices"

  # make the request
  local URL="https://${idphost}/adfs/ls/IdpInitiatedSignOn.aspx"

  # Need to url username and password to cope with special chars
  local encuserid=$(urlencode ${userid})
  local encuserpw=$(urlencode "${userpw}")
  local auth_str=$( echo -n "UserName=${encuserid}&Password=${encuserpw}" )
  local resp=$( curl -s -L -c /tmp/cookies.txt -d "${auth_str}&AuthMethod=FormsAuthentication" ${URL}?loginToRp=${rpid} --write-out %{http_code} --output /tmp/idp-response.xml )

  if [ $resp == 200 ]; then
    testForToken=$( cat -t /tmp/idp-response.xml | xmllint --html --xpath 'string(//input/@name)' 2>/dev/null - )
    if [[ $testForToken == "SAMLResponse" ]]; then
      echo "SAML login request successful!"
      export SAML_RESPONSE=$( cat -t /tmp/idp-response.xml | xmllint --html --xpath 'string(//input[@name="SAMLResponse"]/@value)' 2>/dev/null - )
      rm /tmp/idp-response.xml
      return 0
    else
      echo "SAML login request failed, probably incorrect username/password"
      unset SAML_RESPONSE
      return 1
    fi
  else
    echo "SAML login request failed, http response code $resp"
    unset SAML_RESPONSE
    return $resp
  fi

}

assume() {
  credentials
  local role=""
  local session_name=""
  local assume_result=""
  if [ -z $1 ]; then
    role=$AWS_ASSUME_ROLE
  else
    role=$1
  fi
  session_name=$USER
  [[ "$role" =~ ([0-9]+).role\/(.*) ]] && session_name=$session_name-${BASH_REMATCH[2]}
  assume_result=$( $AWS_CLI sts assume-role \
    --role-arn $role \
    --role-session-name ${session_name:0:32} )
  if [ $?  = 0 ]; then
    extract_creds $assume_result
  else
    echo "Could not assume role; awscli failed"
    return 1
  fi
}

extract_creds() {
    local IN=$@
    local CREDS=$( echo $IN | jq '.Credentials' )
    local ROLE_ARN=$( echo $IN | jq -r '.AssumedRoleUser.Arn' )
    if [ -z "$CREDS" ]; then
        echo "No creds provided -- could not extract"
        return 1
    fi

    export AWS_ACCESS_KEY_ID=$( echo $CREDS | jq -r '.AccessKeyId' )
    export AWS_SECRET_ACCESS_KEY=$( echo $CREDS | jq -r '.SecretAccessKey' )
    export AWS_SECURITY_TOKEN=$( echo $CREDS | jq -r '.SessionToken' )
    export AWS_SESSION_TOKEN=$AWS_SECURITY_TOKEN
    export EXPIRETIME=$( echo $CREDS | jq -r '.Expiration' )
    if [[ "$ROLE_ARN" =~ ([0-9]+).*.role\/(.*)\/(.*) ]]; then
        export AWS_ROLE_SESSION_NAME="${BASH_REMATCH[2]}/${BASH_REMATCH[3]}"
        export AWS_ROLE=${BASH_REMATCH[2]}
        export AWS_ACCOUNT=${BASH_REMATCH[1]}
    else
        echo "Can't match role ARN from returned credentials"
        return 1
    fi
    local DATEPROG=$( date_prog )
    case $DATEPROG in
        GNU)  date_cmd="date --date "$EXPIRETIME" +%s" ;;
        BSD) date_cmd="date -ujf '%Y-%m-%dT%H:%M:%SZ' '$EXPIRETIME' +%s" ;;
        *) echo "Don't know how to handle OS type $UNAME"; return 1 ;;
    esac

    export EXPIRE=$( $date_cmd )

    echo "temporary credentials for aws valid until $EXPIRETIME or until this session ends"
}

date_prog() {
  if date --version >/dev/null 2>&1 ; then
    echo GNU
  else
    echo BSD
  fi
}

extract_asserted_roles() {
  AWS_ROLES=()
  while [[ $1 ]]; do
    if [[ $1 =~ (arn[^<]*) ]]; then
        AWS_ROLES+=("${BASH_REMATCH[1]}");
    fi
    shift
  done
  export AWS_ROLES
}

select_saml_role() {
  for i in "${!AWS_ROLES[@]}"; do
    if [[ ${AWS_ROLES[$i]} =~ ([0-9]+).role\/(.*) ]]; then
        echo -e "$i" "${BASH_REMATCH[2]}"
    else
        echo "Can't match this role to a regex"
    fi
  done
  echo -n "enter the number of the role you want to authenticate with: "
}

urlencode() {
  local length="${#1}"
  for (( i = 0; i < length; i++ )); do
    local c="${1:i:1}"
    case $c in
      [a-zA-Z0-9.~_-]) printf "$c" ;;
    *) printf "$c" | xxd -p -c1 | while read x;do printf "%%%s" "$x";done
  esac
done
}

session() {
  check_expired

  if [ -n "$EXPIRE" ]; then
    echo -e "current aws session expires $EXPIRETIME, for account $AWS_ACCOUNT and role $AWS_ROLE"
fi
}

aws_logout() {
   unset AWS_SECRET_ACCESS_KEY
   unset AWS_ACCESS_KEY_ID
   unset AWS_ACCOUNT
   unset AWS_SECURITY_TOKEN AWS_SESSION_TOKEN
   unset AWS_ROLES AWS_ROLE AWS_ROLE_SESSION_NAME
}
