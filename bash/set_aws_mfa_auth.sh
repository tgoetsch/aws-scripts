#!/bin/bash
# set_aws_mfa_auth.sh
# Created By: Timothy Goetsch
# Creation Date: 03/06/2020
#----------------------------
# Change Log:
#   03/06/2020 - Timothy Goetsch
#     - Initial development

Help() {
    echo "Description:"
    echo "  Authenticate to AWS CLI with MFA token."
    echo
    echo "Requirements:"
    echo "  - AWS CLI is already installed"
    echo "  - AWS CLI is configured for your account/user"
    echo "  - jq is installed to parse the JSON string"
    echo
    echo "Usage:"
    echo "  $ source ./set_aws_mfa_auth.sh [<aws cli profile name>] [<mfa token>]"
    echo "       aws cli profile name: name of the configured AWS CLI profile"
    echo "       mfa token: the 6 number generatd by your MFA device"
    echo
    echo "Examples:"
    echo "  authenticate to the default AWS CLI profile"
    echo "    $ source ./set_aws_mfa_auth.sh 123456"
    echo
    echo "  authenticate to a named AWS CLI profile"
    echo "    $ source ./set_aws_mfa_auth.sh named-profile 123456"
    echo
    echo "  switch to the default profile that has already been authenticated in"
    echo "  the current bash session"
    echo "    $ source ./set_aws_mfa_auth.sh named-profile"
    echo
    echo "  switch to a named profile that has already been authenticated in the"
    echo "  current bash session"
    echo "    $ source ./set_aws_mfa_auth.sh"
    echo
}

# need to unset these env vars or inital aws calls may fail authentication
unset AWS_SECRET_ACCESS_KEY
unset AWS_ACCESS_KEY_ID
unset AWS_SESSION_TOKEN

valid_args=true
failure_detected=false
help_called=false

if [[ $# -ge 1 ]]; then
    # detect if the first argument is a valid token
    if [[ $1 =~ ^[0-9]{6}$ ]]; then
        token_arg=$1
    # check if the -h option was provided
    elif [[ $1 == '-h' ]]; then
        Help
        help_called=true
    # assume it's a profile
    else
        profile_arg=$1
    fi
fi

if [[ $# > 1 ]]; then
    # if token_arg is set, assume the second arg is the profile
    if [[ -v token_arg ]];  then
        profile_arg=$2
    else
        # verify that the second argument is an MFA token
        if [[ $2 =~ ^[0-9]{6}$ ]]; then
            token_arg=$2
        else
            valid_args=false
        fi
    fi
fi

if [[ $valid_args == true ]] && [[ $help_called == false ]]; then
    if [[ -v profile_arg ]]; then
        # set the value for the stored profile variable; remove - from the profile name since that's not a valid variable character
        profile_var=$(echo "aws_token_response_$profile_arg" | sed s/\-//)

        if [[ -v token_arg ]]; then
            # authenticate to aws using the provided profile
            aws_serial_number=$(aws iam list-mfa-devices --profile $profile_arg | jq -r '.MFADevices[0].SerialNumber')
            aws_token_response=$(aws sts get-session-token --profile $profile_arg --serial-number $aws_serial_number --token-code $token_arg)

            # make sure the AWS authentication was successful
            if [[ $? == 0 ]]; then
                # copy the response to a profile variable to be used to switch back to the profile
                # without the need to authenticate again
                IFS= read -r -d '' "$profile_var" <<< $aws_token_response
            else
                failure_detected=true
            fi
        # test to see if the profile response is stored
        elif [[ ${!profile_var} != '' ]]; then
            # load the profile response
            IFS= read -r -d '' aws_token_response <<< "${!profile_var}"
        else
            echo -e "\e[33mYou have not yet authenticated to $profile_arg, please profide the MFA token.\e[39m"
            failure_detected=true
        fi
    else
        if [[ -v token_arg ]]; then
            # authenticate to aws using the default profile
            aws_serial_number=$(aws iam list-mfa-devices | jq -r '.MFADevices[0].SerialNumber')
            aws_token_response=$(aws sts get-session-token --serial-number $aws_serial_number --token-code $token_arg)

            # make sure the authentication was successful
            if [[ $? == 0 ]]; then
                # copy the response to a default profile variable to be used to switch back to the profile
                # without the need to authenticate again
                IFS= read -r -d '' aws_token_response_default <<< $aws_token_response
            else
                failure_detected=true
            fi
        # check to see if the default profile response is stored
        elif [[ -v aws_token_response_default ]]; then
            # load the profile response
            IFS= read -r -d '' aws_token_response <<< $aws_token_response_default
        else
            echo -e "\e[33mYou have not yet authenticated to the default profile, please profide the MFA token.\e[39m"
            failure_detected=true
        fi
    fi

    # if no failures occred, set the env variables for aws cli
    if [[ $failure_detected == false ]]; then
        export AWS_SESSION_TOKEN=$(echo $aws_token_response | jq -r '.Credentials.SessionToken')
        export AWS_SECRET_ACCESS_KEY=$(echo $aws_token_response | jq -r '.Credentials.SecretAccessKey')
        export AWS_ACCESS_KEY_ID=$(echo $aws_token_response | jq -r '.Credentials.AccessKeyId')
    else
        echo -e "\e[33mFailed to authenticate to AWS\e[39m"
        Help
    fi
elif [[ $help_called == false ]]; then
    echo -e "\e[31mArguments provided do not contain a valid mfa token\e[39m"
fi

# need to unset all used vars or they could cause
# the next execution to behave unexplectedly since this
# is ran in the same scope as the user's session
unset aws_token_response
unset aws_serial_number
unset valid_args
unset profile_arg
unset token_arg
unset profile_var
unset failure_detected
