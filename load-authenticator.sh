#!/bin/bash

set -a
source ".env"
set +a

# Create Gitlab Branch
conjur policy update -b root -f <(envsubst < gitlab-branch.yml)

#Load Gitlab authenticator policy
conjur policy update -b root -f <(envsubst < authn-jwt-gitlab.yml)

#Enable the JWT Authenticator in Conjur Cloud
read -p "Press Enter to continue..."
#podman exec conjur-leader evoke variable set CONJUR_AUTHENTICATORS authn,authn-jwt/gitlab-dev

RESULT=$(curl -sSk https://"$CONJUR_MASTER_HOSTNAME":"$CONJUR_MASTER_PORT"/info  | grep "$CONJUR_AUTHENTICATOR_ID" | wc -w)

if [[ $RESULT -ne 2 ]]; then
  echo "Gitlab Authenticator not enabled!"
  exit 1
else
  echo "Gitlab Authenticator $CONJUR_AUTHENTICATOR_ID enabled!"
fi

#We populate the jwks-uri variable with the JWT provider URL:
conjur variable set -i conjur/authn-jwt/$CONJUR_AUTHENTICATOR_ID/token-app-property -v "$GITLAB_TOKEN_APP"
conjur variable set -i conjur/authn-jwt/$CONJUR_AUTHENTICATOR_ID/identity-path -v "$APP_GROUP"
conjur variable set -i conjur/authn-jwt/$CONJUR_AUTHENTICATOR_ID/issuer -v "$GITLAB_ISSUER"
conjur variable set -i conjur/authn-jwt/$CONJUR_AUTHENTICATOR_ID/public-keys -v "{\"type\":\"jwks\", \"value\":$(curl  -k "$GITLAB_JWKS")}"
