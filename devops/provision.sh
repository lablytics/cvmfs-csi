#!/bin/bash

# provision-devenv.sh

AWSCLI_VERSION=2.13.25
TERRAFORM_VERSION=1.6.1

function install_base_packages(){
    sudo apt-get update
    sudo apt-get install -y unzip wget curl openssh-client rsync
}

function install_terraform() {
    cd /tmp
    wget https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_amd64.zip
    unzip terraform_${TERRAFORM_VERSION}_linux_amd64.zip
    sudo mv terraform /usr/local/bin/
    rm terraform_${TERRAFORM_VERSION}_linux_amd64.zip
}

function install_aws_cli() {
    cd /tmp
    curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64-$AWSCLI_VERSION.zip" -o "awscli.zip"
    unzip awscli.zip > /dev/null
    sudo ./aws/install
    cd /tmp
    rm -rf aws
}

function main()
{
    install_base_packages
	install_terraform
	install_aws_cli
}

main