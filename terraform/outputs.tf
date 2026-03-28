output "instance_id" {
  value = vultr_instance.instance_starter.id
}

output "instance_ip" {
  value = vultr_instance.instance_starter.main_ip
}

output "ssh_command" {
  value = "ssh deployer@${vultr_instance.instance_starter.main_ip}"
}