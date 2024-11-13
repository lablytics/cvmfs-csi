provider "aws" {
  region = "us-east-1"
}

data "http" "myip" {
  url = "https://ipv4.icanhazip.com"
}

data "aws_ami" "ubuntu" {
  most_recent = true
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }
  owners = ["099720109477"]
}

resource "aws_security_group" "microk8s_sg" {
  name        = "microk8s-sg"
  description = "Security group for MicroK8s EC2 instance"
  vpc_id      = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.cultivated_ip, "${chomp(data.http.myip.response_body)}/32"]
    description = "Allow SSH access from your public IP"
  }

  ingress {
    from_port   = 16443
    to_port     = 16443
    protocol    = "tcp"
    cidr_blocks = [var.cultivated_ip, "${chomp(data.http.myip.response_body)}/32"]
    description = "Allow K8s access from your public IP"
  }

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = [var.cultivated_ip, "${chomp(data.http.myip.response_body)}/32"]
    description = "Allow port-forward access to Galaxy service"
  }
}

resource "aws_instance" "microk8s_instance" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  subnet_id              = var.subnet_id
  vpc_security_group_ids = [aws_security_group.microk8s_sg.id]
  key_name               = var.key_name

  root_block_device {
    volume_size = 500
    volume_type = "gp2"
  }

  connection {
    type        = "ssh"
    user        = "ubuntu"
    private_key = file(var.private_key_path)
    host        = self.public_ip
  }

  provisioner "file" {
    source      = "${path.module}/setup.sh"
    destination = "/home/ubuntu/setup.sh"
  }

  provisioner "file" {
    source      = "${path.module}/cvmfs-values.yaml"
    destination = "/home/ubuntu/cvmfs-values.yaml"
  }

  provisioner "file" {
    source      = "${path.module}/cvmfs-demo-pod.yaml"
    destination = "/home/ubuntu/cvmfs-demo-pod.yaml"
  }

   provisioner "file" {
    source      = "${path.module}/cvmfs-pvc.yaml"
    destination = "/home/ubuntu/cvmfs-pvc.yaml"
  }
  
  provisioner "remote-exec" {
    inline = [
      "sudo bash /home/ubuntu/setup.sh"
    ]
  }

  tags = {
    Name = "microk8s-dev-instance"
  }
}

