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
# Locals (Safe Ternary)
########################################
locals {
  web_sg_id = var.reuse_existing_sg && length(data.aws_security_group.existing) > 0 ? data.aws_security_group.existing[0].id : aws_security_group.web[0].id

  subnet_to_use = var.subnet_id != "" ? var.subnet_id : (
    length(data.aws_subnets.selected.ids) > 0 ? data.aws_subnets.selected.ids[0] : null
  )

  common_tags = {
    Project     = var.project_name
    Environment = var.environment
  }
}

########################################
# Debug Outputs
########################################
output "vpc_id_used" {
  value = data.aws_vpc.selected.id
}

output "subnet_used" {
  value = local.subnet_to_use
}

output "security_group_used" {
  value = local.web_sg_id
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
  count         = local.subnet_to_use != null ? var.apache_instance_count : 0
  ami           = "ami-0f5ee92e2d63afc18"
  instance_type = var.instance_type
  subnet_id     = local.subnet_to_use
  key_name      = var.keypair_name
  vpc_security_group_ids = [local.web_sg_id]

  tags = merge(local.common_tags, { Name = "apache-${count.index}" })
}

resource "aws_instance" "nginx" {
  count         = local.subnet_to_use != null ? var.nginx_instance_count : 0
  ami           = "ami-0f5ee92e2d63afc18"
  instance_type = var.instance_type
  subnet_id     = local.subnet_to_use
  key_name      = var.keypair_name
  vpc_security_group_ids = [local.web_sg_id]

  tags = merge(local.common_tags, { Name = "nginx-${count.index}" })
}

########################################
# Variables
########################################
variable "aws_region" {
  type = string
}

variable "environment" {
  type = string
}

variable "project_name" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "subnet_id" {
  type    = string
  default = ""
}

variable "reuse_existing_sg" {
  type    = bool
  default = false
}

variable "existing_sg_name" {
  type    = string
  default = ""
}

variable "jenkins_ip" {
  type = string
}

variable "instance_type" {
  type = string
}

variable "apache_instance_count" {
  type    = number
  default = 1
}

variable "nginx_instance_count" {
  type    = number
  default = 1
}

variable "keypair_name" {
  type = string
}

variable "create_key_pair" {
  type    = bool
  default = false
}

variable "public_key_openssh" {
  type    = string
  default = ""
}

variable "ansible_user" {
  type = string
}
