provider "aws" {
  region = "us-east-2"
}


# pull ubuntu ami id from AWS provider rather than hard-coding
# reference https://developer.hashicorp.com/terraform/tutorials/aws-get-started/aws-create
data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  owners = ["099720109477"] # Canonical
}


# Create VPC and network basics
# reference https://registry.terraform.io/modules/terraform-aws-modules/vpc/aws/latest

module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "dberner-challenge-vpc"
  cidr = "10.1.0.0/16"

  azs             = ["us-east-2a", "us-east-2b"]
  private_subnets = ["10.1.20.0/24", "10.1.21.0/24"]
  public_subnets  = ["10.1.0.0/24", "10.1.80.0/24", "10.1.81.0/24"]

  enable_nat_gateway = true
  enable_vpn_gateway = true

  tags = {
    Terraform   = "true"
    Environment = "challenge"
  }

  manage_default_vpc = true
  default_vpc_name   = "dberner-challenge-vpc"
}


# security group for the management subnet
# reference https://github.com/terraform-aws-modules/terraform-aws-security-group
module "management-sg" {
  source = "terraform-aws-modules/security-group/aws//modules/ssh"

  name        = "management-sg"
  description = "security group for management subnet"
  vpc_id      = module.vpc.vpc_id

  ingress_cidr_blocks = ["73.17.79.176/32"] # my home IP
  ingress_rules       = ["ssh-tcp"]
}

# Create instance running in the management network, "bastion"
# reference https://github.com/terraform-aws-modules/terraform-aws-ec2-instance
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


# security groups for the app servers
# reference https://github.com/terraform-aws-modules/terraform-aws-security-group
module "application-ssh-sg" {
  source = "terraform-aws-modules/security-group/aws//modules/ssh"

  name        = "application-ssh-sg"
  description = "ssh access from the management netowrk to the app servers"
  vpc_id      = module.vpc.vpc_id

  ingress_cidr_blocks = [element(module.vpc.public_subnets_cidr_blocks, 0)] # the management network
  ingress_rules       = ["ssh-tcp"]
}

# Create ASG for the app servers
# reference https://registry.terraform.io/modules/terraform-aws-modules/autoscaling/aws/latest
module "application_asg" {
  source = "terraform-aws-modules/autoscaling/aws"

  name                      = "application-asg"
  min_size                  = 2
  max_size                  = 6
  desired_capacity          = 2
  wait_for_capacity_timeout = 0
  health_check_type         = "EC2"
  vpc_zone_identifier       = module.vpc.private_subnets
  key_name                  = "dberner-coalfire-sre-challenge-key"
  security_groups           = [module.application-ssh-sg.security_group_id]

  initial_lifecycle_hooks = [
    {
      name                  = "ExampleStartupLifecycleHook"
      default_result        = "CONTINUE"
      heartbeat_timeout     = 60
      lifecycle_transition  = "autoscaling:EC2_INSTANCE_LAUNCHING"
      notification_metadata = jsonencode({ "hello" = "world" })
    },
    {
      name                  = "ExampleTerminationLifecycleHook"
      default_result        = "CONTINUE"
      heartbeat_timeout     = 180
      lifecycle_transition  = "autoscaling:EC2_INSTANCE_TERMINATING"
      notification_metadata = jsonencode({ "goodbye" = "world" })
    }
  ]

  instance_refresh = {
    strategy = "Rolling"
    preferences = {
      checkpoint_delay       = 600
      checkpoint_percentages = [35, 70, 100]
      instance_warmup        = 300
      min_healthy_percentage = 50
      max_healthy_percentage = 100
    }
    triggers = ["tag"]
  }

  launch_template_name        = "application-asg"
  launch_template_description = "Launch template for application instances"
  update_default_version      = true

  image_id      = data.aws_ami.ubuntu.id
  instance_type = "t2.micro"

  create_iam_instance_profile = true
  iam_role_name               = "application-asg"
  iam_role_path               = "/ec2/"
  iam_role_description        = "IAM role for application asg"
  iam_role_tags = {
    CustomIamRole = "Yes"
  }
  iam_role_policies = {
    AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  }

  capacity_reservation_specification = {
    capacity_reservation_preference = "open"
  }

  metadata_options = {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }
}
