#!/bin/bash
# Author: Patryk Grabarczyk <grabarczyk.patryk@gmail.com>
# 04.10.2019

##### Parameters #####
aws_original_profile=$1
aws_mfa_token=$2
aws_mfa_profile_name="mfa"
session_duration=43200 #You can choose from 900 seconds (15 minutes) to 129,600 seconds (36 hours). I set it to 43200 (12 hours).
######################

create_new_credentials() {
    local aws_original_profile=$1
    local aws_mfa_token=$2
    local aws_mfa_profile_name=$3
    local session_duration=$4

    local mfa_serial_number=$(aws configure --profile "${aws_original_profile}" get aws_arn_mfa)
    if [ -z "${mfa_serial_number}" ] ; then
        echo "ERROR mfa_serial_number is empty for profile ${mfa_serial_number}. Set it in default credential file with key aws_arn_mfa"
        exit 1
    fi

    local tmp_credentials=$(aws sts get-session-token \
        --profile "${aws_original_profile}" \
        --serial-number "${mfa_serial_number}"  \
        --token-code "${aws_mfa_token}" \
        --duration-second "${session_duration}" )
    if [ $? -ne 0 ]; then
        echo "ERROR. Check your profile or MFA"
        exit 2
    fi

    local aws_access_key_id=$(echo "${tmp_credentials}" | jq .Credentials.AccessKeyId | sed "s/\"//g")
    local aws_secret_access_key=$(echo "${tmp_credentials}" | jq .Credentials.SecretAccessKey | sed "s/\"//g")
    local aws_session_token=$(echo "${tmp_credentials}" | jq .Credentials.SessionToken | sed "s/\"//g")

    aws configure --profile "${aws_mfa_profile_name}" set aws_access_key_id ${aws_access_key_id}
    aws configure --profile "${aws_mfa_profile_name}" set aws_secret_access_key ${aws_secret_access_key}
    aws configure --profile "${aws_mfa_profile_name}" set aws_session_token ${aws_session_token}

    echo "Done, now you can use your mfa profile ${aws_mfa_profile_name}"
}

create_new_credentials "${aws_original_profile}" "${aws_mfa_token}" "${aws_mfa_profile_name}" "${session_duration}"