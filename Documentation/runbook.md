# Runbook

## Prerequisites

1. A working AWs and Terraform environment (See the Deployment section of the README.md)
2. Contact David Berner about creating a user and keypair for accessing the AWS environment
3. Clone the code repo (again see the Deployment section of the README.md)
4. Contact David Berner for a copy of the ssh private key
5. Download the key, make node of the file path to it

## Deployment

```
terraform init
terraform apply
```

## Connecting to the bastion

1. Collect the hostname of the bastion instance
`aws ec2 describe-instances | grep PublicDnsName`

Example output:
```
📦 dberner@coalfire :) [main] challenge-dberner]$ aws ec2 describe-instances | grep PublicDnsName
                                "PublicDnsName": "ec2-3-135-246-64.us-east-2.compute.amazonaws.com",
                                        "PublicDnsName": "ec2-3-135-246-64.us-east-2.compute.amazonaws.com",
                    "PublicDnsName": "ec2-3-135-246-64.us-east-2.compute.amazonaws.com",
                    "PublicDnsName": "",
                    "PublicDnsName": "",
📦 dberner@coalfire :) [main] challenge-dberner]$ 
```

4. ssh to the instance using the path to the key file and the hostname
```
ssh -i <path_to_ssh_key> ubuntu@<public_dns_name>
```

## Connecting to application instances

1. Collect the IP addresss of of the application instances
`for i in $(aws autoscaling describe-auto-scaling-instances | grep InstanceId | cut -d'"' -f4); do aws ec2 describe-instances --instance-ids $i | grep 'PrivateIpAddress":'; done`

Example output:
```
📦 dberner@coalfire :) [main] challenge-dberner]$ for i in $(aws autoscaling describe-auto-scaling-instances | grep InstanceId | cut -d'"' -f4); do aws ec2 describe-instances --instance-ids $i | grep 'PrivateIpAddress":'; done
                            "PrivateIpAddress": "10.1.21.145",
                                    "PrivateIpAddress": "10.1.21.145"
                    "PrivateIpAddress": "10.1.21.145"
                            "PrivateIpAddress": "10.1.20.57",
                                    "PrivateIpAddress": "10.1.20.57"
                    "PrivateIpAddress": "10.1.20.57"
📦 dberner@coalfire :) [main] challenge-dberner]$ 
```
2. Log in to the bastion (see above)
3. Copy the ssh private key to the ~/.ssh/ directory of the bastion
  - name the file `id_rsa`
4. Change the permissions of the ~/.ssh/<path_to_private_ssh_key> to 600
`chmod 600 ~/.ssh/id_rsa`
5. ssh to the instance
`ssh ubuntu@<ip_address_of_desired_instance>`
## Service outages

As currently configured, there's no unique data to save or restore. Reapply the terraform code to redeploy the site in the event of any issues. (See the deployment section above or in the README.md)
