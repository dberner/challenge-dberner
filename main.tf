provider "aws" {
  region = "us-east-2"
}

# Create VPC and network basics
# reference https://registry.terraform.io/modules/terraform-aws-modules/vpc/aws/latest

module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "dberner-challenge-vpc"
  cidr = "10.1.0.0/16"

  azs             = ["us-east-2a", "us-east-2b"]
  private_subnets = ["10.1.20.0/24", "10.1.21.0/24"]
  public_subnets  = ["10.1.0.0/24"]

  enable_nat_gateway = true
  enable_vpn_gateway = true

  tags = {
    Terraform   = "true"
    Environment = "challenge"
  }

  manage_default_vpc = true
  default_vpc_name   = "dberner-challenge-vpc"
}

module "management-sg" {
  source = "terraform-aws-modules/security-group/aws//modules/ssh"

  name        = "management-sg"
  description = "security group for management subnet"
  vpc_id      = module.vpc.vpc_id

  ingress_cidr_blocks = ["73.17.79.176/32"] # my home IP
  ingress_rules       = ["ssh-tcp"]
}

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  owners = ["099720109477"] # Canonical
}

module "bastion_ec2_instance" {
  source = "terraform-aws-modules/ec2-instance/aws"

  name = "bastion"

  ami                         = data.aws_ami.ubuntu.id
  instance_type               = "t2.micro"
  key_name                    = "dberner-coalfire-sre-challenge-key"
  availability_zone           = element(module.vpc.azs, 0)
  subnet_id                   = element(module.vpc.public_subnets, 0)
  vpc_security_group_ids      = [module.management-sg.security_group_id]
  associate_public_ip_address = true
}
