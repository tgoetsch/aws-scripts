#!/bin/bash
current_identity=$(aws sts get-caller-identity | jq -r '.Arn' | sed -r 's/.*:([^:]+)/\1/;s/.*\/([^\/]+)/\1/')
new_session=$(aws sts assume-role --role-arn $1 --role-session-name $current_identity)

export AWS_ACCESS_KEY_ID=$(echo $new_session | jq -r '.Credentials.AccessKeyId')
export AWS_SECRET_ACCESS_KEY=$(echo $new_session | jq -r '.Credentials.SecretAccessKey')
export AWS_SESSION_TOKEN=$(echo $new_session | jq -r '.Credentials.SessionToken')
unset current_identity
unset new_session
