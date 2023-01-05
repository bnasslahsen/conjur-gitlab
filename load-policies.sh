#!/bin/bash

set -a
source ".env"
set +a

#Load Gitlab root policy
envsubst < authn-jwt-gitlab.yml > authn-jwt-gitlab.yml.tmp
conjur policy update -f authn-jwt-gitlab.yml.tmp -b root
rm authn-jwt-gitlab.yml.tmp

#podman exec dap evoke variable set CONJUR_AUTHENTICATORS authn,authn-jwt/jenkins,authn-jwt/jwt-cluster,authn-k8s/dev-cluster,authn-jwt/gitlab-ci
#Verify that the Gitlab Authenticator is configured and allowlisted
RESULT=$(curl -sSk https://"$CONJUR_MASTER_HOSTNAME":"$CONJUR_MASTER_PORT"/info  | grep "$CONJUR_AUTHENTICATOR_ID" | wc -w)

if [[ $RESULT -ne 2 ]]; then
  echo "Gitlab Authenticator not enabled!"
  exit 1
else
  echo "Gitlab Authenticator $CONJUR_AUTHENTICATOR_ID enabled!"
fi

#We populate the jwks-uri variable with the JWT provider URL:
conjur variable set -i conjur/authn-jwt/$CONJUR_AUTHENTICATOR_ID/jwks-uri -v "$GITLAB_JWKS"
conjur variable set -i conjur/authn-jwt/$CONJUR_AUTHENTICATOR_ID/token-app-property -v "$GITLAB_TOKEN_APP"
conjur variable set -i conjur/authn-jwt/$CONJUR_AUTHENTICATOR_ID/identity-path -v "$GITLAB_IDENTITY"
conjur variable set -i conjur/authn-jwt/$CONJUR_AUTHENTICATOR_ID/issuer -v "$GITLAB_ISSUER"

envsubst < gitlab-host.yml > gitlab-host.yml.tmp
conjur policy update -f gitlab-host.yml.tmp -b root
rm gitlab-host.yml.tmp

envsubst < gitlab-grants.yml > gitlab-grants.yml.tmp
conjur policy update -f gitlab-grants.yml.tmp -b root
rm gitlab-grants.yml.tmp

conjur policy update -b root -f gitlab-secrets.yml
conjur variable set -i ci/gitlab/secrets/gitlab_username -v "$GIT_USER"
conjur variable set -i ci/gitlab/secrets/gitlab_password -v "$GIT_PASS"

#echo $CI_JOB_JWT | base64
response="$(curl -k -s -w '%{http_code}' --request POST https://"$CONJUR_MASTER_HOSTNAME":"$CONJUR_MASTER_PORT"/authn-jwt/$CONJUR_AUTHENTICATOR_ID/$CONJUR_ACCOUNT/authenticate --header 'Content-Type: application/x-www-form-urlencoded' --header "Accept-Encoding: base64" --data-urlencode "jwt=$CI_JOB_JWT")"
http_code=${response: -3}

if [[ $http_code -ne 200 ]]; then
  echo "Gitlab Authentication failed $response"
  exit 1
else
  echo "Gitlab Authentication successful!"
fi