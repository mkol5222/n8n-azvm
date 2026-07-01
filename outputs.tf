output "resource_group_name" {
  description = "Name of the resource group"
  value       = azurerm_resource_group.n8n.name
}

output "vm_name" {
  description = "Name of the virtual machine"
  value       = azurerm_linux_virtual_machine.n8n.name
}

output "public_ip_address" {
  description = "Public IP address of the VM"
  value       = azurerm_public_ip.n8n.ip_address
}

output "n8n_url" {
  description = "URL to access n8n (HTTPS)"
  value       = "https://${azurerm_public_ip.n8n.fqdn}"
}

output "fqdn" {
  description = "Fully qualified domain name of the VM"
  value       = azurerm_public_ip.n8n.fqdn
}

output "ssh_command" {
  description = "SSH command to connect to the VM"
  value       = "ssh ${var.admin_username}@${azurerm_public_ip.n8n.fqdn}"
}

output "vm_id" {
  description = "ID of the virtual machine"
  value       = azurerm_linux_virtual_machine.n8n.id
}

output "mcp_everything_url" {
  description = "MCP Everything server URL (internal Docker network, reachable from n8n)"
  value       = "http://mcp-everything:5077/mcp"
}

output "mcp_management_logs_url" {
  description = "MCP Management Logs server URL (internal Docker network)"
  value       = "http://mcp-management-logs:5078/mcp"
}

output "mcp_quantum_management_url" {
  description = "MCP Quantum Management server URL (internal Docker network)"
  value       = "http://mcp-quantum-management:5079/mcp"
}

output "n8n_owner_email" {
  description = "N8N owner account email"
  value       = var.n8n_owner_email
}

output "n8n_owner_password" {
  description = "N8N owner account password"
  value       = var.n8n_owner_password
  sensitive   = true
}

output "generated_ssh_private_key" {
  description = "Generated SSH private key (only populated if ssh_public_key was not provided)"
  value       = var.ssh_public_key == "" ? tls_private_key.ssh[0].private_key_pem : null
  sensitive   = true
}
