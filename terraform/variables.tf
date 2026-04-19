variable "vultr_api_key" {
  description = "Vultr API key"
  type        = string
  sensitive   = true
}

variable "ssh_public_key_path" {
  description = "Path to SSH public key"
  type        = string
  default     = "~/.ssh/github_actions_deploy.pub"
}

variable "django_secret_key" {
  description = "Django SECRET_KEY."
  type        = string
  sensitive   = true
}

variable "db_name" {
  description = "PostgreSQL database name."
  type        = string
  default     = "instance_starter"
}

variable "db_user" {
  description = "PostgreSQL application user."
  type        = string
  default     = "instance_starter_user"
}

variable "db_password" {
  description = "PostgreSQL application user password."
  type        = string
  sensitive   = true
}

variable "django_superuser_username" {
  description = "Username for the initial Django admin superuser."
  type        = string
  default     = "admin"
}

variable "django_superuser_email" {
  description = "Email for the initial Django admin superuser."
  type        = string
  default     = ""
}

variable "django_superuser_password" {
  description = "Password for the initial Django admin superuser."
  type        = string
  sensitive   = true
}