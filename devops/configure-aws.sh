#!/bin/bash

KEYNAME="devbox-key-pair" # YOUR KEYNAME

if [ -z "$AWS_ACCESS_KEY" ] || [ -z "$AWS_SECRET_ACCESS_KEY" ] || [ -z "$AWS_DEFAULT_REGION" ]; then
    echo "Missing AWS environment variables: ACCESS_KEY, SECRET_KEY, or REGION"
    exit 1
fi

# Check if key file exists for the keypair in the current directory
if [ ! -f "$KEYNAME.pem" ]; then
    echo "Key file $KEYNAME.pem not found in the current directory."
    exit 1
fi

sudo chmod 400 $KEYNAME.pem

aws configure set aws_access_key_id "$AWS_ACCESS_KEY"
aws configure set aws_secret_access_key "$AWS_SECRET_ACCESS_KEY"
aws configure set default.region "$AWS_DEFAULT_REGION"
aws configure set output "$OUTPUT"

echo "AWS CLI configured with the provided credentials."