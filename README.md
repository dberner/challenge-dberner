# Coalfire SRE AWS Technical Challenge


## Site Overview

The diagram below represents the site as initially planned. Unfortunately, the Terraform code doesn't currently fully apply, so **the diagrammed ALB is not currently deployable.**

The diagram presents a single VPC spanning 2 Availability Zones. Each AZ hosts public and private subnets. A public Management subnet for the bastion EC2 instance exists in only one AZ. Both AZs contain a public subnet for an ALB listener, and a private subnet for ASG instances. An Internet Gateway allows traffic to and from the Internet into the VPC. Traffic can pass from the IG to the bastion instance, and to the ALB. The ALB passes traffic to Listeners which pass traffic to the ASG instances in their private subnets. (Access via SSH from the bastion to the ASG instances is not pictured.)

![](challenge-diagram.png)

## Deployment

### Prerequisites

An AWS account and workstation configured with Terraform and appropriate credentials to deploy to AWS are required. Consult the appropriate documentation from [Amazon](https://docs.aws.amazon.com/accounts/latest/reference/manage-acct-creating.html) and [Hashicorp](https://developer.hashicorp.com/terraform/tutorials/aws-get-started) for this setup.

### Deployment instructions

1. Clone the code repository: [https://github.com/dberner/challenge-dberner](https://github.com/dberner/challenge-dberner)
```
git clone https://github.com/dberner/challenge-dberner
```

2. Navigate into the repository directory
```
cd challenge-dberner
```

3. Run Terraform
```
terraform init
terraform apply
```

## Discussion

### Design

I planned to follow the specification as closely as possible and set up a bare bones site with 3 instances in 2 AZs, with appropriate visibility to the Internet and subnet allocations as described. Once a basic site was deployed I'd planned to install a simple app and then provide whatever storage and backend was required for the app. A minimum viable app would need a single S3 storage bucket and a simple database, perhaps on another instance or using an AWS service.

### Assumptions

1. I had assumed that I would be able to finish the deployment in a reasonable time frame.
2. 

### Improvement plan

1. 

### General Notes
First, I looked at Coalfire's AWS Terraform modules, I started writing code with these but quickly realized I wouldn't be able to understand them enough to fully implement in the time available for the challenge.

The top Google search result for AWS Terraform modules is [Terraform AWS Modules](https://registry.terraform.io/namespaces/terraform-aws-modules), this seemed to be a strong endorsement. These modules have reasonably comprehensible example code and looked like they'd work for my implementation plan: there are modules for handling VPC, Security Groups, EC2 Instances, ASG, and ALB.

I started by deploying the VPC and network configuraton. This was straightforward. The security group for the management subnet was next, then the management EC2 instance. After these were deployed I successfully tested connecting to the bastion instance via SSH.

Encouraged by this, I started working on the ASG. First by adding another security group for ssh to the ASG instances from the bastion instance, then  setting up the ASG itself and deploying a couple of instances into the application subnets. This was less straigthforward for me, and I fought with syntax, resource names, and module outputs. Once I had it deploying I was able to test hopping through the bastion into the ASG instances.

Next, I started working on the ALB. Unfortunately I ran into a roadblock with the [Terraform AWS Modules ALB module](https://registry.terraform.io/modules/terraform-aws-modules/alb/aws/latest). I was able to deploy an ALB but not attach it to the ASG. The ALB module example code doesn't document ASG targets. Given more time I'd work on implementing the ALB via Hashicorp's AWS provider resources directly, but getting this far has already exceeded my time budget for the project, given my inexperience with AWS and Terraform.

It seems like ASGs are not well supported by this module author, my next step was to install apache on the ASG instances, but I found the `user_data` input in the ASG module configuration doesn't seem run the provided bash script on the instances. Again, given more time I'd approach this by writing directly with Hashicorp's provider resources directly.

I've commented out the ALB code in the current main.tf. It was previously running but I wanted to leave the target group code in place for future experimentation.

## References

### terraform-aws-modules
These are the modules I used:
  - [vpc](https://registry.terraform.io/modules/terraform-aws-modules/vpc/aws/latest)
  - [security-group](https://registry.terraform.io/modules/terraform-aws-modules/security-group/aws/latest)
  - [ec2-instance](https://registry.terraform.io/modules/terraform-aws-modules/ec2-instance/aws/latest)
  - [autoscaling](https://registry.terraform.io/modules/terraform-aws-modules/autoscaling/aws/latest)
  - [alb](https://registry.terraform.io/modules/terraform-aws-modules/alb/aws/latest)

Code examples:
- [ASG examples the autoscaling module](https://github.com/terraform-aws-modules/terraform-aws-autoscaling/tree/master/examples/complete)
- [ALB examples from the alb module](https://github.com/terraform-aws-modules/terraform-aws-alb/blob/master/docs/patterns.md)

### AWS documentation consulted

- [Guide about VPC & subnetting](https://docs.aws.amazon.com/vpc/latest/userguide/vpc-example-private-subnets-nat.html)
- [Documentation on ALB subnets and routing](https://docs.aws.amazon.com/prescriptive-guidance/latest/load-balancer-stickiness/subnets-routing.html)
- [Documentation on ALB creation](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/create-application-load-balancer.html)
- [Documentation about ALB target groups](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/load-balancer-target-groups.html)
- [User guide about ELB](https://docs.aws.amazon.com/autoscaling/ec2/userguide/getting-started-elastic-load-balancing.html)
- [Documentation about attaching ELB and ASG](https://docs.aws.amazon.com/autoscaling/ec2/userguide/attach-load-balancer-asg.html)
- [Documentation about instance user data](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/user-data.html)
- [Tutorial for setting up ASG and LB](https://docs.aws.amazon.com/autoscaling/ec2/userguide/tutorial-ec2-auto-scaling-load-balancer.html)

### Other resources consulted
- [reddit post](https://www.reddit.com/r/Terraform/comments/1kkx9jb/help_associating_asg_with_alb_target_group_using/) about target group problems with ASG and ALB
- [example code on traffic source attachment](https://github.com/terraform-aws-modules/terraform-aws-autoscaling/blob/d2975372e3c6530aade7797063c67dab9d0315d8/examples/complete/main.tf#L52) referenced by above
- Hashicorp's AWS provider documentation on [autoscaling traffic source attachments](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/autoscaling_traffic_source_attachment)
