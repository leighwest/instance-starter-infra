# Instance Starter Infrastructure

Terraform configuration for deploying the Instance Starter application to Vultr.

## Overview

This repository contains Infrastructure as Code (IaC) for provisioning a Vultr VPS to host the [Instance Starter](https://github.com/yourusername/instance_starter) Django application - a web interface for managing EC2 instance start/stop operations.

## Architecture

- **Provider:** Vultr
- **Region:** Melbourne (mel)
- **Server:** 1GB RAM / 1 vCPU
- **OS:** Ubuntu 22.04 LTS
- **Configuration:** Cloud-init for automated setup
- **Services:** Docker, Docker Compose

## Prerequisites

- [Terraform](https://www.terraform.io/downloads) >= 1.0
- Vultr account with API access
- SSH key pair

## Setup

### 1. Clone the Repository

```bash
git clone https://github.com/yourusername/instance_starter_infra.git
cd instance_starter_infra/terraform
```

### 2. Get Vultr API Key

1. Log into [Vultr](https://my.vultr.com/)
2. Account → API → Personal Access Token
3. Generate new token and copy it

### 3. Get Your Public IP

```bash
curl ifconfig.me
```

### 4. Configure Variables

```bash
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` with your actual values:

```hcl
vultr_api_key       = "your-actual-vultr-api-key"
your_ip             = "your.actual.ip.address"
ssh_public_key_path = "~/.ssh/id_rsa.pub"
```

⚠️ **Never commit `terraform.tfvars`** - it contains secrets!

### 5. Initialize Terraform

```bash
terraform init
```

## Usage

### Deploy Infrastructure

```bash
# Preview changes
terraform plan

# Apply changes
terraform apply

# Type 'yes' when prompted
```

### Get Server IP

```bash
terraform output instance_ip
```

### SSH to Server

```bash
ssh root@$(terraform output -raw instance_ip)

# Or use the deployer user (created by cloud-init)
ssh deployer@$(terraform output -raw instance_ip)
```

### Destroy Infrastructure

```bash
terraform destroy

# Type 'yes' when prompted
```

## What Gets Provisioned

### Server Configuration

- **Packages:** Docker, Docker Compose, Git, Curl
- **Users:** `deployer` user with sudo and Docker access
- **Swap:** 1GB swap file (important for 1GB RAM)
- **Firewall:** UFW enabled

### Firewall Rules

- **Port 22 (SSH):** Your IP only
- **Port 80 (HTTP):** Open to all
- **Port 443 (HTTPS):** Open to all

### Cloud-init Actions

The server runs the following on first boot:

1. Updates all packages
2. Installs Docker and Docker Compose
3. Creates deployer user
4. Configures 1GB swap file
5. Sets up firewall rules

## Deploying the Application

After infrastructure is provisioned:

```bash
# SSH to server
ssh deployer@YOUR_SERVER_IP

# Clone application
git clone https://github.com/yourusername/instance_starter.git
cd instance_starter

# Create .env file
nano .env
# (add your production environment variables)

# Start services
docker-compose up -d

# Check status
docker-compose ps
docker-compose logs -f
```

## File Structure

```
instance_starter_infra/
├── terraform/
│   ├── main.tf                   # Main Terraform configuration
│   ├── variables.tf              # Variable definitions
│   ├── outputs.tf                # Output values
│   ├── cloud-init.yml            # Server initialization script
│   ├── terraform.tfvars          # Your secrets (gitignored)
│   └── terraform.tfvars.example  # Template for variables
├── .gitignore                    # Git ignore rules
└── README.md                     # This file
```

## Troubleshooting

### Can't SSH to Server

1. Check firewall rules allow your current IP:

```bash
   curl ifconfig.me  # Compare to your_ip in terraform.tfvars
```

2. Wait 2-3 minutes after `terraform apply` for cloud-init to complete

3. Check instance status in [Vultr Console](https://my.vultr.com/)

### Cloud-init Status

```bash
# SSH to server, then check cloud-init status
cloud-init status

# View cloud-init logs
sudo cat /var/log/cloud-init-output.log
```

### Terraform State Issues

```bash
# If state is corrupted or out of sync
terraform refresh

# Or re-import resources manually
terraform import vultr_instance.instance_starter YOUR_INSTANCE_ID
```

## Security Notes

- ✅ SSH access restricted to your IP only
- ✅ Secrets in `terraform.tfvars` are gitignored
- ✅ Firewall (UFW) enabled by default
- ⚠️ Remember to update SSH rules when your IP changes
- ⚠️ Keep your Vultr API key secure

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Submit a pull request

## License

MIT

## Related Projects

- [Instance Starter Application](https://github.com/yourusername/instance_starter) - The Django app that runs on this infrastructure

## Support

For issues related to:

- **Infrastructure provisioning:** Open an issue in this repo
- **Application deployment:** See the [instance_starter](https://github.com/yourusername/instance_starter) repo
- **Vultr platform:** Contact [Vultr Support](https://www.vultr.com/support/)
