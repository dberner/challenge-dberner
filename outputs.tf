output "bastion_hostname" {
  value = module.bastion_ec2_instance.public_dns
}
