# Region & environment
aws_region            = "ap-south-1"
environment           = "production"
project_name          = "devops-webapp"

# Your VPC
vpc_id                = "vpc-0bb695c41dc9db0a4"
subnet_id             = ""   # leave empty to auto-pick the first subnet in that VPC

# Security group behavior
reuse_existing_sg     = true
existing_sg_name      = "web-server-sg"

# EC2 & SSH
instance_type         = "t3.micro"
apache_instance_count = 2
nginx_instance_count  = 2

# Key pair management
keypair_name          = "deploy-key"
create_key_pair       = true
public_key_openssh    = ""
ansible_user          = "ubuntu"

# Optional (for local terraform plan)
jenkins_ip            = "3.6.38.53"
