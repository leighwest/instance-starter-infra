output "instance_id" {
  value = vultr_instance.instance_starter.id
}

output "reserved_ip" {
  value = vultr_reserved_ip.main.subnet
}

output "ssh_command" {
  value = "ssh -i ~/.ssh/instance_starter_deploy deployer@${vultr_reserved_ip.main.subnet}"
}

output "site_url" {
  value = "http://${vultr_reserved_ip.main.subnet}"
}