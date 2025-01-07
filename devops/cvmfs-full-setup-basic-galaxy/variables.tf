variable "aws_region" {
  default = "us-east-1"
}

variable "instance_type" {
  default = "m5.4xlarge"
}

variable "web_node_port" {
  default = 30700
}

variable "domain_name" {
  description = "The domain for the galaxy website"
}

variable "vpc_id" {
  description = "The VPC ID where the instance will be deployed"
}

variable "subnet_id" {
  description = "The Subnet ID where the instance will be deployed"
}

variable "key_name" {
  description = "The key name to use to connect to the EC2 Instances"
}

variable "ami_name" {
  description = "The AMI ID to use for the instance"
}

variable "cultivated_ip" {
    description = "The IP address of the Cultivated Code server"
}

variable "private_key_path" {
  description = "The path to the private key file"
}