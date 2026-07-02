# n8n on Azure VM - Terraform Module

Deploy [n8n](https://n8n.io) workflow automation on Azure with automatic SSL, pre-configured owner account, and optional MCP servers.

## TLDR

```bash
# OPTIONAL: Customize terraform.tfvars with your values
cp terraform.tfvars.example terraform.tfvars
az login
make up
```

## Features

- Ubuntu 22.04 LTS VM with Docker
- Traefik reverse proxy with automatic Let's Encrypt SSL
- n8n with persistent storage
- Pre-provisioned owner account (skip setup wizard)
- Optional MCP (Model Context Protocol) servers for AI integrations
- Health check script to verify deployment


## Prerequisites

- Azure account with sufficient permissions to create resources
- Terraform installed
- Azure CLI installed and authenticated


## Quick Start

```bash
# 1. Configure - OPTIONAL (you can answer questions interactively on make up)
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values

# 2. Deploy
make up

# Or manually:
terraform init
terraform apply
./wait-for-n8n.sh
```

## Makefile Commands

| Command | Description |
|---------|-------------|
| `make up` | Initialize and deploy (includes wait script) |
| `make down` | Destroy all resources |
| `make plan` | Preview changes |
| `make wait` | Wait for n8n to become reachable |
| `make status` | Check deployment status |

## Required Variables

| Variable | Description |
|----------|-------------|
| `ssh_public_key` | Your SSH public key for VM access |
| `ssl_email` | Email for Let's Encrypt SSL certificate |

## Optional Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `prefix` | `falcon` | Resource naming prefix |
| `location` | `westeurope` | Azure region |
| `vm_size` | `Standard_B2s` | VM size |
| `timezone` | `UTC` | Timezone for n8n |
| `n8n_owner_email` | `admin@example.local` | Pre-provisioned owner email |
| `n8n_owner_password` | - | Pre-provisioned owner password |
| `mcp_management_host` | - | Check Point Management host |
| `mcp_management_user` | - | MCP server username |
| `mcp_management_password` | - | MCP server password |

## Outputs

After deployment, `./wait-for-n8n.sh` displays:

- **n8n URL**: `https://{prefix}-n8n.{region}.cloudapp.azure.com`
- **Login credentials**: Email and password for the owner account
- **MCP Server URLs**: Internal URLs for use in n8n workflows

## MCP Servers

The deployment includes three MCP servers (accessible within n8n):

| Server | Internal URL |
|--------|--------------|
| Everything (demo) | `http://mcp-everything:5077/mcp` |
| Management Logs | `http://mcp-management-logs:5078/mcp` |
| Quantum Management | `http://mcp-quantum-management:5079/mcp` |

## Architecture

```
                Internet
                    │
                    ▼
┌─────────────────────────────────────────┐
│              Azure VM                   │
│  ┌─────────────────────────────────┐    │
│  │         Traefik                 │    │
│  │    (SSL termination)            │    │
│  └──────────────┬──────────────────┘    │
│                 │                       │
│  ┌──────────────▼──────────────────┐    │
│  │            n8n                  │    │
│  │    (workflow automation)        │    │
│  └──────────────┬──────────────────┘    │
│                 │                       │
│  ┌──────────────▼──────────────────┐    │
│  │        MCP Servers              │    │
│  │  (everything, mgmt-logs, qm)    │    │
│  └─────────────────────────────────┘    │
└─────────────────────────────────────────┘
```

## Troubleshooting

### Monitor cloud-init progress
```bash
ssh azureuser@<fqdn> 'sudo tail -f /var/log/cloud-init-output.log'
```

### Check container status
```bash
ssh azureuser@<fqdn> 'cd /opt/n8n && docker compose ps'
```

### View n8n logs
```bash
ssh azureuser@<fqdn> 'cd /opt/n8n && docker compose logs n8n'
```

### SSL certificate issues
Let's Encrypt has rate limits (5 certs per domain per week). If you hit the limit:
- Wait for the rate limit to reset, or
- Change the `prefix` to get a new domain name

## License

MIT
