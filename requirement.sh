#!/bin/bash


#Settings before execution
# aws configure > your aws account information
# edit : ~/.aws/credential
# add : aws_arn_mfa : your aws account mfa device

#aws linux
sudo yum update -y
sudo yum install jq -y


#Ubuntu
#sudo apt update
#sudo apt install jq 