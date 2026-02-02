########################################
# Provider
########################################
provider "aws" {
  region = var.aws_region
}

########################################
# Data Sources
########################################

# VPC
data "aws_vpc" "selected" {
  id = var.vpc_id
}

# Subnets in VPC (auto-pick if subnet_id is empty)
data "aws_subnets" "selected" {
  filter {
    name   = "vpc-id"
    values = [var.vpc_id]
  }
}

# Existing Security Group (only when reuse is enabled)
data "aws_security_group" "existing" {
  count  = var.reuse_existing_sg ? 1 : 0
  name   = var.existing_sg_name
  vpc_id = var.vpc_id
}

########################################
# Security Group (Create only if needed)
########################################

resource "aws_security_group" "web" {
  count       = var.reuse_existing_sg ? 0 : 1
  name        = "${var.project_name}-web-sg-${var.environment}"
  description = "Web security group for ${var.project_name}"
  vpc_id      = var.vpc_id

  ingress {
    description = "SSH from Jenkins"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["${var.jenkins_ip}/32"]
  }

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project_name}-sg"
    Environment = var.environment
  }
}

########################################
# Locals (IMPORTANT – FIXED TERNARY)
########################################

locals {
  web_sg_id = var.reuse_existing_sg ? data.aws_security_group.existing[0].id : aws_security_group.web[0].id

  subnet_to_use = var.subnet_id != "" ? var.subnet_id : data.aws_subnets.selected.ids[0]

  common_tags = {
    Project     = var.project_name
    Environment = var.environment
  }
}

########################################
# Key Pair (Optional Creation)
########################################

resource "tls_private_key" "this" {
  count     = var.create_key_pair && var.public_key_openssh == "" ? 1 : 0
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "this" {
  count      = var.create_key_pair ? 1 : 0
  key_name   = var.keypair_name
  public_key = var.public_key_openssh != "" ? var.public_key_openssh : tls_private_key.this[0].public_key_openssh
}

########################################
# EC2 Instances
########################################

resource "aws_instance" "apache" {
  count         = var.apache_instance_count
  ami           = "ami-0f5ee92e2d63afc18"
  instance_type = var.instance_type
  subnet_id     = local.subnet_to_use
  key_name      = var.keypair_name

  vpc_security_group_ids = [local.web_sg_id]

  tags = merge(
    local.common_tags,
    {
      Name = "apache-${count.index}"
    }
  )
}

resource "aws_instance" "nginx" {
  count         = var.nginx_instance_count
  ami           = "ami-0f5ee92e2d63afc18"
  instance_type = var.instance_type
  subnet_id     = local.subnet_to_use
  key_name      = var.keypair_name

  vpc_security_group_ids = [local.web_sg_id]

  tags = merge(
    local.common_tags,
    {
      Name = "nginx-${count.index}"
    }
  )
}
########################################
# Core / Environment
########################################

variable "aws_region" {
  type        = string
  description = "AWS region"
}

variable "environment" {
  type        = string
  description = "Environment name"
}

variable "project_name" {
  type        = string
  description = "Project name"
}

########################################
# Network
########################################

variable "vpc_id" {
  type        = string
  description = "VPC ID"
}

variable "subnet_id" {
  type        = string
  description = "Subnet ID (optional)"
  default     = ""
}

########################################
# Security Group
########################################

variable "reuse_existing_sg" {
  type        = bool
  description = "Reuse an existing security group"
  default     = false
}

variable "existing_sg_name" {
  type        = string
  description = "Existing security group name"
  default     = ""
}

########################################
# Jenkins / CI
########################################

variable "jenkins_ip" {
  type        = string
  description = "Public IP of Jenkins agent"
}

########################################
# EC2
########################################

variable "instance_type" {
  type        = string
  description = "EC2 instance type"
}

variable "apache_instance_count" {
  type        = number
  description = "Number of Apache instances"
  default     = 1
}

variable "nginx_instance_count" {
  type        = number
  description = "Number of Nginx instances"
  default     = 1
}

########################################
# Key Pair
########################################

variable "keypair_name" {
  type        = string
  description = "Key pair name"
}

variable "create_key_pair" {
  type        = bool
  description = "Create key pair or not"
  default     = false
}

variable "public_key_openssh" {
  type        = string
  description = "Public SSH key"
  default     = ""
}

########################################
# Ansible
########################################

variable "ansible_user" {
  type        = string
  description = "Ansible SSH user"
}
