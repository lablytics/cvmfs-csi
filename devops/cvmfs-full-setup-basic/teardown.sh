#!/bin/bash

echo "Destroying Terraform-managed resources..."
terraform init 
terraform destroy -auto-approve 

rm -f terraform.tfstate
rm -f terraform.tfstate.backup
rm -f terraform.tfstate.lock.info
rm -f .terraform.lock.hcl
rm -rf .terraform
echo "Terraform resources destroyed."