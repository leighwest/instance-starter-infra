terraform {
  required_providers {
    vultr = {
      source  = "vultr/vultr"
      version = "~> 2.0"
    }
  }
}

provider "vultr" {
  api_key = var.vultr_api_key
}

locals {
  nginx_config = indent(6, file("${path.module}/../nginx/instance-starter.conf"))
}

# Get Melbourne region ID
data "vultr_region" "melbourne" {
  filter {
    name   = "id"
    values = ["mel"]
  }
}

# SSH Key
resource "vultr_ssh_key" "main" {
  name    = "instance-starter-key"
  ssh_key = file(pathexpand(var.ssh_public_key_path))
}

# Server 
resource "vultr_instance" "instance_starter" {
  plan                = "vc2-1c-1gb"  
  region              = data.vultr_region.melbourne.id
  os_id               = 1743
  label               = "instance-starter"
  hostname            = "instance-starter"
  enable_ipv6         = true
  backups             = "disabled"
  ddos_protection     = false
  activation_email    = false
  firewall_group_id   = vultr_firewall_group.main.id
  reserved_ip_id      = vultr_reserved_ip.main.id
  
  ssh_key_ids = [vultr_ssh_key.main.id]

  user_data = templatefile("${path.module}/cloud-init.yml", {
  aws_access_key_id         = var.aws_access_key_id
  aws_secret_access_key     = var.aws_secret_access_key
  aws_region                = var.aws_region
  db_name                   = var.db_name
  db_user                   = var.db_user
  db_password               = var.db_password
  django_secret_key         = var.django_secret_key
  django_allowed_hosts      = "${vultr_reserved_ip.main.subnet},${var.domain},localhost,127.0.0.1"
  django_superuser_username = var.django_superuser_username
  django_superuser_email    = var.django_superuser_email
  django_superuser_password = var.django_superuser_password
  app_repo_url              = "https://github.com/leighwest/instance-starter"
  app_branch                = "main"
  nginx_config              = local.nginx_config
  deployer_ssh_public_key   = file(pathexpand(var.ssh_public_key_path))
  domain                    = var.domain
  certbot_email             = var.certbot_email
})
  
  tags = ["instance-starter", "production"]
}

# Firewall
resource "vultr_firewall_group" "main" {
  description = "instance-starter-firewall"
}

resource "vultr_firewall_rule" "ssh" {
  firewall_group_id = vultr_firewall_group.main.id
  protocol          = "tcp"
  ip_type           = "v4"
  subnet            = "0.0.0.0"
  subnet_size       = 0
  port              = "22"
}

resource "vultr_firewall_rule" "http" {
  firewall_group_id = vultr_firewall_group.main.id
  protocol          = "tcp"
  ip_type           = "v4"
  subnet            = "0.0.0.0"
  subnet_size       = 0
  port              = "80"
}

resource "vultr_firewall_rule" "https" {
  firewall_group_id = vultr_firewall_group.main.id
  protocol          = "tcp"
  ip_type           = "v4"
  subnet            = "0.0.0.0"
  subnet_size       = 0
  port              = "443"
}

resource "vultr_reserved_ip" "main" {
  region  = data.vultr_region.melbourne.id
  ip_type = "v4"
  label   = "instance-starter-ip"
}