#!/bin/bash

# Set your AWS region
AWS_REGION="us-east-1"  # Change this to the region where your EC2 instance is running

# Set your EC2 key pair path
KEY_PAIR_PATH="../devbox-key-pair.pem"  # Change this to the correct path to your key pair

# Set your EC2 tag name to find the instance
INSTANCE_TAG_NAME="microk8s-dev-instance"

# Get the public IP of the instance with the tag name 'microk8s-dev-instance'
INSTANCE_PUBLIC_IP=$(aws ec2 describe-instances \
    --region $AWS_REGION \
    --filters "Name=tag:Name,Values=$INSTANCE_TAG_NAME" "Name=instance-state-name,Values=running" \
    --query "Reservations[*].Instances[*].PublicIpAddress" \
    --output text)

# Check if an IP address was found
if [ -z "$INSTANCE_PUBLIC_IP" ]; then
  echo "Instance with tag name '$INSTANCE_TAG_NAME' is not running or doesn't exist."
  exit 1
fi

# Connect to the instance via SSH
echo "Connecting to EC2 instance with IP: $INSTANCE_PUBLIC_IP"

scp -i "$KEY_PAIR_PATH" ubuntu@$INSTANCE_PUBLIC_IP:/home/ubuntu/.kube/config-public .
ssh -i "$KEY_PAIR_PATH" ubuntu@$INSTANCE_PUBLIC_IP