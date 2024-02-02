#!/usr/bin/env bash

# Requirements 
#   - curl
#   - jq
#   - awk
#  
#  ./examples/credential_helper/auth.sh <<< '{"uri":"https://public.ecr.aws/token/?scope\u003drepository:lambda/python:pull\u0026service\u003dpublic.ecr.aws"}'
#  ./examples/credential_helper/auth.sh <<< '{"uri":"https://public.ecr.aws/v2/lambda/python/manifests/3.11.2024.01.25.10"}'
function log () {
    echo "$1" >> /tmp/oci_auth.log
}

log ""
log "Authenticating"

input=$(cat)
log "Payload: $input"

uri=$(jq -r ".uri" <<< $input)
log "URI: $uri"

host="$(echo $uri | awk -F[/:] '{print $4}')"
log "Host: $host"

if [[ $input == *"/token"* ]]; then
    log "Auth: None"
    echo "{}"
    exit 0
fi

# This will write the response to stdout in a format that Bazels credential helper protocol understands.
# Since this is called by Bazel, users won't bee seeing output of this.
curl -fsSL https://$host/token | jq '{headers:{"Authorization": [("Bearer " + .token)]}}'
log "Auth: Complete"

# Alternatively you can call an external program such as `docker-credential-ecr-login` to perform the token exchange.