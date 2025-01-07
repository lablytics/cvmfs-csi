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

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [var.cultivated_ip, "${chomp(data.http.myip.response_body)}/32"]
    description = "Allow HTTP access on port 80"
  }

   # Allow access to the NodePort (e.g., 32000)
  ingress {
    from_port   = var.web_node_port                         
    to_port     = var.web_node_port                         
    protocol    = "tcp"
    cidr_blocks = [var.cultivated_ip, "${chomp(data.http.myip.response_body)}/32"]
    description = "Allow public access to NodePort service"
  }
}

# Step 1: Allocate the Elastic IP
resource "aws_eip" "microk8s_eip" {
  domain = "vpc"
}

# Step 2: Create and configure the EC2 instance without immediate provisioning
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

  tags = {
    Name = "microk8s-dev-instance"
  }
}

# Step 3: Associate the Elastic IP with the EC2 instance
resource "aws_eip_association" "microk8s_eip_assoc" {
  instance_id   = aws_instance.microk8s_instance.id
  allocation_id = aws_eip.microk8s_eip.id
}

# Step 4: Use a null_resource to run provisioners after the Elastic IP is associated
resource "null_resource" "post_eip_provisioning" {
  depends_on = [aws_eip_association.microk8s_eip_assoc] # Ensure Elastic IP is assigned

  # Provisioners to copy files and run setup script via SSH
  provisioner "file" {
    source      = "${path.module}/setup.sh"
    destination = "/home/ubuntu/setup.sh"
    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = file(var.private_key_path)
      host        = aws_eip.microk8s_eip.public_ip
    }
  }

  provisioner "file" {
    source      = "${path.module}/cvmfs-values.yaml"
    destination = "/home/ubuntu/cvmfs-values.yaml"
    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = file(var.private_key_path)
      host        = aws_eip.microk8s_eip.public_ip
    }
  }

  provisioner "file" {
    source      = "${path.module}/galaxy-pvc.yaml"
    destination = "/home/ubuntu/galaxy-pvc.yaml"
    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = file(var.private_key_path)
      host        = aws_eip.microk8s_eip.public_ip
    }
  }

  provisioner "file" {
    source      = "${path.module}/galaxy-values.yaml"
    destination = "/home/ubuntu/galaxy-values.yaml"
    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = file(var.private_key_path)
      host        = aws_eip.microk8s_eip.public_ip
    }
  }

  provisioner "file" {
    source      = "${path.module}/galaxy-services.sh"
    destination = "/home/ubuntu/galaxy-services.sh"
    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = file(var.private_key_path)
      host        = aws_eip.microk8s_eip.public_ip
    }
  }

  provisioner "remote-exec" {
    inline = [
      "sudo bash /home/ubuntu/setup.sh",
      "sudo chmod +x /home/ubuntu/galaxy-services.sh",
    ]
    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = file(var.private_key_path)
      host        = aws_eip.microk8s_eip.public_ip
    }
  }
}

