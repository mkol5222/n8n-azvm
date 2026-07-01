variable "prefix" {
  description = "Prefix for all resources (e.g., animal name like 'tiger', 'falcon')"
  type        = string
  default     = "falcon"
}

variable "location" {
  description = "Azure region for resources"
  type        = string
  default     = "westeurope"
}

variable "vm_size" {
  description = "Azure VM size"
  type        = string
  default     = "Standard_B2s"
}

variable "admin_username" {
  description = "Admin username for the VM"
  type        = string
  default     = "azureuser"
}

variable "ssh_public_key" {
  description = "SSH public key for VM access (leave empty to auto-generate)"
  type        = string
  default     = ""
}

variable "ssl_email" {
  description = "Email address for Let's Encrypt SSL certificate registration"
  type        = string
  default     = "ssl@labs.cloudguard.rocks"
}

variable "timezone" {
  description = "Timezone for n8n (e.g., Europe/Berlin, America/New_York)"
  type        = string
  default     = "Europe/Berlin"
}

variable "n8n_basic_auth_user" {
  description = "Basic auth username for n8n (optional, leave empty to disable)"
  type        = string
  default     = ""
}

variable "n8n_basic_auth_password" {
  description = "Basic auth password for n8n (optional, leave empty to disable)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "allowed_ssh_cidr" {
  description = "CIDR block allowed to SSH into the VM (e.g., your IP: 1.2.3.4/32)"
  type        = string
  default     = "0.0.0.0/0"
}

variable "tags" {
  description = "Additional tags for resources"
  type        = map(string)
  default     = {}
}

# N8N Owner Account Configuration
variable "n8n_owner_email" {
  description = "Email for the pre-provisioned n8n owner account"
  type        = string
  default     = "admin@example.local"
}

variable "n8n_owner_password" {
  description = "Password for the pre-provisioned n8n owner account (min 8 chars, 1 number, 1 uppercase)"
  type        = string
  default     = "ChangeMe123!"
  sensitive   = true
}

variable "n8n_owner_first_name" {
  description = "First name for the n8n owner account"
  type        = string
  default     = "Guru"
}

variable "n8n_owner_last_name" {
  description = "Last name for the n8n owner account"
  type        = string
  default     = "Admin"
}

# MCP Server Configuration
variable "mcp_management_host" {
  description = "Hostname for Check Point Management MCP servers"
  type        = string
  default     = ""
}

variable "mcp_management_user" {
  description = "Username for Check Point Management MCP servers"
  type        = string
  default     = ""
}

variable "mcp_management_password" {
  description = "Password for Check Point Management MCP servers"
  type        = string
  default     = ""
  sensitive   = true
}
