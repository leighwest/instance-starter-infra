# Instance Starter Infrastructure

Terraform configuration for deploying the Instance Starter application to Vultr.

## Overview

This repository contains Infrastructure as Code (IaC) for provisioning a Vultr VPS to host the [Instance Starter](https://github.com/leighwest/instance-starter) Django application - a web interface for managing EC2 instance start/stop operations.

## Production Deployment

**Reserved IP:** 139.84.203.187 (permanent — survives reprovisioning)  
**Deployed:** March 2026  
**Status:** Active  
**Application:** https://instance-starter.leighwest.dev  
**CI/CD:** GitHub Actions (self-hosted runner on server)

## Architecture

- **Provider:** Vultr
- **Region:** Melbourne (mel)
- **Server:** 1GB RAM / 1 vCPU
- **OS:** Ubuntu 22.04 LTS
- **Configuration:** Cloud-init for zero-touch bootstrap
- **Services:** Docker, Docker Compose, Nginx, Certbot
- **CI/CD:** Self-hosted GitHub Actions runner

```
Internet (port 80/443)
    ↓
Nginx (reverse proxy + SSL termination)
    ├─→ /static/ → staticfiles/
    ├─→ /ws/ → localhost:8000 (WebSocket)
    └─→ / → localhost:8000 (Django)
        ↓
Docker Compose
    ├─ web (Django/Daphne)
    ├─ db (PostgreSQL 14)
    ├─ redis (Redis 7)
    ├─ celery_worker
    └─ celery_beat
```

## Prerequisites

- [Terraform](https://www.terraform.io/downloads) >= 1.0
- Vultr account with API access
- ed25519 SSH key pair (generated in WSL)

## Setup

### 1. Clone the Repository

```bash
git clone https://github.com/leighwest/instance-starter-infra.git
cd instance-starter-infra/terraform
```

### 2. Generate SSH Key

```bash
ssh-keygen -t ed25519 -C "instance-starter-deploy" -f ~/.ssh/instance_starter_deploy
```

### 3. Get Vultr API Key

1. Log into [Vultr](https://my.vultr.com/)
2. Click your name (top right) → **API**
3. Click **Create API Key** and copy it immediately — only shown once

### 4. Configure Variables

```bash
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` with your actual values:

```hcl
vultr_api_key             = "your-vultr-api-key"
ssh_public_key_path       = "~/.ssh/instance_starter_deploy.pub"
django_secret_key         = "your-django-secret-key"
db_password               = "your-db-password"
django_superuser_password = "your-superuser-password"
django_superuser_email    = "your@email.com"
certbot_email             = "your@email.com"
```

⚠️ **Never commit `terraform.tfvars`** - it contains secrets!

### 5. Initialize Terraform

```bash
terraform init
```

## Usage

### Deploy Infrastructure

```bash
terraform plan
terraform apply
```

Cloud-init handles the full bootstrap automatically:

1. Installs Docker, Docker Compose, Nginx, Certbot
2. Creates `deployer` user with SSH key auth only
3. Writes `.env`, clones app repo, starts Docker Compose stack
4. Runs migrations, collectstatic, ensure_superuser
5. Configures Nginx and obtains SSL certificate from Let's Encrypt

### SSH to Server

```bash
# As deployer (day-to-day)
ssh -i ~/.ssh/instance_starter_deploy deployer@139.84.203.187

# As root (emergencies only)
ssh -i ~/.ssh/instance_starter_deploy root@139.84.203.187
```

### Destroy Infrastructure

```bash
terraform destroy
```

⚠️ **Known issue:** Reserved IP detach fails during destroy. Manually delete the reserved IP from the Vultr dashboard, then run:

```bash
terraform state rm vultr_reserved_ip.main
terraform apply
```

## What Gets Provisioned

### Server Configuration

- **Packages:** Docker, Docker Compose v2, Nginx, Certbot, Git
- **Users:** `deployer` with sudo and Docker access, SSH key auth only
- **Swap:** 1GB swap file
- **Firewall:** UFW + Vultr firewall group
- **SSL:** Let's Encrypt certificate via Certbot, auto-renewal via systemd timer

### Firewall Rules

- **Port 22 (SSH):** Open to all — secured by ed25519 key, password auth disabled
- **Port 80 (HTTP):** Open to all — redirects to HTTPS
- **Port 443 (HTTPS):** Open to all

### Cloud-init Bootstrap (zero-touch)

1. Installs Docker, Docker Compose, Nginx, Certbot
2. Creates `deployer` user, writes SSH authorized_keys
3. Disables password authentication
4. Configures swap
5. Clones app repo, writes `.env`
6. Starts Docker Compose stack
7. Runs migrations, collectstatic, ensure_superuser
8. Configures and enables Nginx
9. Obtains SSL certificate, configures HTTPS and HTTP → HTTPS redirect

## Post-Provisioning: GitHub Actions Runner

The self-hosted runner must be set up manually after each `terraform apply`. SSH into the server as deployer and follow the runner setup instructions from:

**GitHub repo → Settings → Actions → Runners → New self-hosted runner**

Select Linux / x64, then run the provided commands as the `deployer` user. Install as a systemd service:

```bash
cd ~/actions-runner
sudo ./svc.sh install deployer
sudo ./svc.sh start
sudo ./svc.sh status
```

The runner will survive reboots and listen for jobs automatically.

## CI/CD Pipeline

Pushing to `main` in the app repo triggers the GitHub Actions workflow:

1. Checks out code on the runner
2. `git pull` latest changes
3. `docker-compose down && docker-compose up -d`
4. Runs migrations and collectstatic

No secrets required in GitHub — the runner executes locally on the server.

## File Structure

```
instance-starter-infra/
├── terraform/
│   ├── main.tf                   # Vultr resources
│   ├── variables.tf              # Variable definitions
│   ├── outputs.tf                # Reserved IP, SSH command, site URL
│   ├── cloud-init.yml            # Zero-touch server bootstrap
│   ├── terraform.tfvars          # Secrets (gitignored)
│   └── terraform.tfvars.example  # Safe-to-commit template
├── nginx/
│   └── instance-starter.conf     # Nginx reverse proxy config
├── .gitignore
└── README.md
```

## Troubleshooting

### Can't SSH to Server

```bash
# Check cloud-init completed
ssh -i ~/.ssh/instance_starter_deploy root@139.84.203.187
tail /var/log/cloud-init-output.log
```

### Cloud-init Failed

```bash
cat /var/log/cloud-init-output.log | grep -i error
```

### Docker Issues

```bash
cd /home/deployer/instance-starter
docker-compose ps
docker-compose logs -f web
```

### GitHub Actions Runner Not Picking Up Jobs

```bash
cd /home/deployer/actions-runner
sudo ./svc.sh status
sudo ./svc.sh start
```

### SSL Certificate

```bash
certbot certificates          # list certificates and expiry
certbot renew --dry-run       # test auto-renewal
systemctl status certbot.timer
```

## Security Notes

- ✅ Password authentication disabled (`PasswordAuthentication no`)
- ✅ SSH access via ed25519 key only
- ✅ Dedicated deploy key (`instance_starter_deploy`) separate from personal keys
- ✅ Secrets in `terraform.tfvars` are gitignored
- ✅ Vultr firewall group attached to instance
- ✅ Self-hosted runner — no SSH secrets stored in GitHub
- ✅ HTTPS enforced — HTTP redirects to HTTPS
- ✅ Let's Encrypt certificate with automatic renewal
- ⚠️ Keep your Vultr API key secure and rotate regularly
- ⚠️ Vultr API ACL should be restricted to your IP where possible

## Related Projects

- [Instance Starter Application](https://github.com/leighwest/instance-starter) - The Django app that runs on this infrastructure
