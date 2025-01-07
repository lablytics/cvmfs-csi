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


FILES=("galaxy-values.yaml" "galaxy-pvc.yaml" "galaxy-services.sh")
for f in "${FILES[@]}"
do
  rsync -avz -e "ssh -i $KEY_PAIR_PATH" "$f" ubuntu@$INSTANCE_PUBLIC_IP:/home/ubuntu/
done