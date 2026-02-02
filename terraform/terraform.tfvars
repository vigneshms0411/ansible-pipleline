aws_region            = "ap-south-1"
vpc_id                = "vpc-0abcd1234ef567890"  # Replace with your actual VPC ID
subnet_id             = ""                        # Leave empty to auto-pick a subnet
reuse_existing_sg     = false
existing_sg_name      = ""                        # Only needed if reuse_existing_sg=true
jenkins_ip            = "http://65.0.94.171/"
keypair_name          = "my-key"                  # Must exist if create_key_pair=false
project_name          = "rentify"
environment           = "dev"
instance_type         = "t2.micro"
apache_instance_count = 1
nginx_instance_count  = 1
create_key_pair       = false
public_key_openssh    = ""
ansible_user          = "ubuntu"
