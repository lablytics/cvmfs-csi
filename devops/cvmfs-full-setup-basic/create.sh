#!/bin/bash

terraform init
terraform validate
terraform plan -out=qc-microk8s-dev-plan
terraform apply qc-microk8s-dev-plan