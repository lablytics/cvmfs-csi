#!/bin/bash

echo "Destroying Terraform-managed resources..."
terraform init 
terraform destroy -auto-approve 
echo "Terraform resources destroyed."