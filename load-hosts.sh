#!/bin/bash

set -a
source ".env"
set +a


conjur policy update -b $APP_GROUP -f <(envsubst < gitlab-hosts.yml)

conjur policy update -b vault01/LOBUser1 -f <(envsubst < gitlab-hosts-grants.yml)