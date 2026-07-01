terraform {
  required_version = ">= 1.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.0"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = ">= 4.0"
    }
  }
}

provider "azurerm" {
  features {}
}

# Generate random encryption key for n8n
resource "random_password" "n8n_encryption_key" {
  length  = 32
  special = false
}

# Generate random suffix for DNS name (8 hex digits, retained until destroyed)
resource "random_id" "dns_suffix" {
  byte_length = 4
}

# Generate SSH key pair if not provided
resource "tls_private_key" "ssh" {
  count     = var.ssh_public_key == "" ? 1 : 0
  algorithm = "RSA"
  rsa_bits  = 4096
}

locals {
  ssh_public_key = var.ssh_public_key != "" ? var.ssh_public_key : tls_private_key.ssh[0].public_key_openssh
  resource_prefix = var.prefix
  dns_label       = "${var.prefix}-n8n-${random_id.dns_suffix.hex}"
  fqdn            = "${local.dns_label}.${var.location}.cloudapp.azure.com"

  # Bcrypt hash for n8n owner - escape $ as $$ for docker-compose
  n8n_owner_password_hash_escaped = replace(bcrypt(var.n8n_owner_password), "$", "$$")

  default_tags = {
    Project   = "n8n"
    ManagedBy = "Terraform"
  }
  tags = merge(local.default_tags, var.tags)
}

# Resource Group
resource "azurerm_resource_group" "n8n" {
  name     = "rg-${local.resource_prefix}-n8n"
  location = var.location
  tags     = local.tags
}

# Virtual Network
resource "azurerm_virtual_network" "n8n" {
  name                = "vnet-${local.resource_prefix}-n8n"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.n8n.location
  resource_group_name = azurerm_resource_group.n8n.name
  tags                = local.tags
}

# Subnet
resource "azurerm_subnet" "n8n" {
  name                 = "snet-${local.resource_prefix}-n8n"
  resource_group_name  = azurerm_resource_group.n8n.name
  virtual_network_name = azurerm_virtual_network.n8n.name
  address_prefixes     = ["10.0.1.0/24"]
}

# Network Security Group
resource "azurerm_network_security_group" "n8n" {
  name                = "nsg-${local.resource_prefix}-n8n"
  location            = azurerm_resource_group.n8n.location
  resource_group_name = azurerm_resource_group.n8n.name
  tags                = local.tags

  security_rule {
    name                       = "AllowHTTP"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "AllowHTTPS"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "AllowSSH"
    priority                   = 120
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = var.allowed_ssh_cidr
    destination_address_prefix = "*"
  }
}

# Public IP with DNS label
resource "azurerm_public_ip" "n8n" {
  name                = "pip-${local.resource_prefix}-n8n"
  location            = azurerm_resource_group.n8n.location
  resource_group_name = azurerm_resource_group.n8n.name
  allocation_method   = "Static"
  sku                 = "Standard"
  domain_name_label   = local.dns_label
  tags                = local.tags
}

# Network Interface
resource "azurerm_network_interface" "n8n" {
  name                = "nic-${local.resource_prefix}-n8n"
  location            = azurerm_resource_group.n8n.location
  resource_group_name = azurerm_resource_group.n8n.name
  tags                = local.tags

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.n8n.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.n8n.id
  }
}

# Associate NSG with NIC
resource "azurerm_network_interface_security_group_association" "n8n" {
  network_interface_id      = azurerm_network_interface.n8n.id
  network_security_group_id = azurerm_network_security_group.n8n.id
}

# Cloud-init configuration from external template
locals {
  cloud_init = templatefile("${path.module}/templates/cloud-init.yaml.tpl", {
    fqdn                            = local.fqdn
    ssl_email                       = var.ssl_email
    timezone                        = var.timezone
    n8n_basic_auth_active           = var.n8n_basic_auth_user != "" ? "true" : "false"
    n8n_basic_auth_user             = var.n8n_basic_auth_user
    n8n_basic_auth_password         = var.n8n_basic_auth_password
    n8n_encryption_key              = random_password.n8n_encryption_key.result
    n8n_owner_email                 = var.n8n_owner_email
    n8n_owner_first_name            = var.n8n_owner_first_name
    n8n_owner_last_name             = var.n8n_owner_last_name
    n8n_owner_password_hash_escaped = local.n8n_owner_password_hash_escaped
    admin_username                  = var.admin_username
    mcp_management_host             = var.mcp_management_host
    mcp_management_user             = var.mcp_management_user
    mcp_management_password         = var.mcp_management_password
  })
}

# Ubuntu LTS VM
resource "azurerm_linux_virtual_machine" "n8n" {
  name                = "vm-${local.resource_prefix}-n8n"
  resource_group_name = azurerm_resource_group.n8n.name
  location            = azurerm_resource_group.n8n.location
  size                = var.vm_size
  admin_username      = var.admin_username
  tags                = local.tags

  network_interface_ids = [
    azurerm_network_interface.n8n.id
  ]

  admin_ssh_key {
    username   = var.admin_username
    public_key = local.ssh_public_key
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
    disk_size_gb         = 30
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

  custom_data = base64encode(local.cloud_init)
}
