provider "aws" {
  region = "us-east-2"
}

# VPC and Nework configuration
# reference https://github.com/Coalfire-CF/terraform-aws-vpc-nfw?tab=readme-ov-file#usage
module "dberner_challenge_vpc" {
  source   = "git::https://github.com/Coalfire-CF/terraform-aws-vpc-nfw.git?ref=v3.0.3"
  vpc_name = "challenge-vpc"
  cidr     = "10.1.0.0/16"
  azs      = ["us-east-2a", "us-east-2b"]

  resource_prefix = "dberner"
  subnets = [
    {
      tag               = "application"
      cidr              = "10.1.0.0/24"
      type              = "private"
      availability_zone = "us-east-2a"
    },
    {
      tag               = "management"
      cidr              = "10.1.1.0/24"
      type              = "public"
      availability_zone = "us-east-2b"
    },
    {
      tag               = "backend"
      cidr              = "10.1.2.0/24"
      type              = "private"
      availability_zone = "us-east-2b"
    }
  ]

  single_nat_gateway      = false
  enable_nat_gateway      = true
  one_nat_gateway_per_az  = true
  enable_vpn_gateway      = false
  enable_dns_hostnames    = true
  map_public_ip_on_launch = true

  flow_log_destination_type              = "cloud-watch-logs"
  cloudwatch_log_group_retention_in_days = 30
}

# Securty Group configuration
# reference https://github.com/Coalfire-CF/terraform-aws-securitygroup?tab=readme-ov-file#usage
module "application_sg" {
  source = "github.com/Coalfire-CF/terraform-aws-securitygroup?ref=v1.0.1" # Path to security group module
  name   = "dberner_challenge_application_sg"
  vpc_id = module.dberner_challenge_vpc.vpc_id

  ingress_rules = {
    # "allow_http" = {
    #   ip_protocol = "tcp"
    #   from_port   = "80"
    #   to_port     = "80"
    #   cidr_ipv4   = "10.1.0.0/24"
    # }
    "allow_ssh" = {
      ip_protocol = "tcp"
      from_port   = "22"
      to_port     = "22"
      cidr_ipv4   = "10.1.1.0/24" # allow ssh from the management subnet
    }
  }

  egress_rules = {
    "allow_all_egress" = {
      ip_protocol = "-1"
      cidr_ipv4   = "0.0.0.0/0"
      description = "allow all egress"
    }
  }
}

module "management_sg" {
  source = "github.com/Coalfire-CF/terraform-aws-securitygroup?ref=v1.0.1" # Path to security group module
  name   = "dberner_challenge_management_sg"
  vpc_id = module.dberner_challenge_vpc.vpc_id

  ingress_rules = {
    "allow_ssh" = {
      ip_protocol = "tcp"
      from_port   = "22"
      to_port     = "22"
      cidr_ipv4   = "73.17.79.176/32" # allow ssh from my home IP
    }
  }

  egress_rules = {
    "allow_all_egress" = {
      ip_protocol = "-1"
      cidr_ipv4   = "0.0.0.0/0"
      description = "allow all egress"
    }
  }
}


# create ec2 instance for bastion host in management subnet
# reference https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/instance

# get most recent ubuntu ami
data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  owners = ["099720109477"] # Canonical
}

# deploy instance
resource "aws_instance" "bastion" {
  ami                    = data.aws_ami.ubuntu.id
  availability_zone      = "us-east-2b"
  instance_type          = "t2.micro"
  vpc_security_group_ids = [module.management_sg.id]

  tags = {
    Name = "bastion"
  }
}
