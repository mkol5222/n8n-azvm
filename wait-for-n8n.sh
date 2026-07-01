#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
MAX_ATTEMPTS=${MAX_ATTEMPTS:-60}
SLEEP_INTERVAL=${SLEEP_INTERVAL:-10}

echo -e "${CYAN}Fetching Terraform outputs...${NC}"

# Get outputs from Terraform
N8N_URL=$(terraform output -raw n8n_url 2>/dev/null) || {
    echo -e "${RED}Error: Failed to get n8n_url from Terraform outputs.${NC}"
    echo -e "${YELLOW}Make sure Terraform has been applied successfully.${NC}"
    exit 1
}

MCP_EVERYTHING_URL=$(terraform output -raw mcp_everything_url 2>/dev/null) || MCP_EVERYTHING_URL="N/A"
MCP_MANAGEMENT_LOGS_URL=$(terraform output -raw mcp_management_logs_url 2>/dev/null) || MCP_MANAGEMENT_LOGS_URL="N/A"
MCP_QUANTUM_MANAGEMENT_URL=$(terraform output -raw mcp_quantum_management_url 2>/dev/null) || MCP_QUANTUM_MANAGEMENT_URL="N/A"
N8N_OWNER_EMAIL=$(terraform output -raw n8n_owner_email 2>/dev/null) || N8N_OWNER_EMAIL="N/A"
N8N_OWNER_PASSWORD=$(terraform output -raw n8n_owner_password 2>/dev/null) || N8N_OWNER_PASSWORD="N/A"

echo -e "${YELLOW}Waiting for N8N to become reachable at: ${N8N_URL}${NC}"
echo -e "${YELLOW}This may take several minutes while the VM initializes...${NC}"
echo ""

attempt=1
while [ $attempt -le $MAX_ATTEMPTS ]; do
    printf "\r${CYAN}Attempt %d/%d - Checking connectivity...${NC}" "$attempt" "$MAX_ATTEMPTS"

    # Use curl with insecure flag initially (Let's Encrypt cert may not be ready yet)
    if curl -s -o /dev/null -w "%{http_code}" --max-time 10 -k "${N8N_URL}" 2>/dev/null | grep -qE "^(200|301|302|303|307|308)$"; then
        echo ""
        echo ""
        echo -e "${GREEN}✓ N8N is now reachable!${NC}"
        echo ""
        echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
        echo -e "${GREEN}                      N8N DEPLOYMENT READY                      ${NC}"
        echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
        echo ""
        echo -e "${CYAN}N8N URL:${NC}"
        echo -e "  ${GREEN}${N8N_URL}${NC}"
        echo ""
        echo -e "${CYAN}Login Credentials:${NC}"
        echo -e "  Email:    ${YELLOW}${N8N_OWNER_EMAIL}${NC}"
        echo -e "  Password: ${YELLOW}${N8N_OWNER_PASSWORD}${NC}"
        echo ""
        echo -e "${CYAN}MCP Servers (accessible from within N8N workflows):${NC}"
        echo -e "  • Everything:         ${YELLOW}${MCP_EVERYTHING_URL}${NC}"
        echo -e "  • Management Logs:    ${YELLOW}${MCP_MANAGEMENT_LOGS_URL}${NC}"
        echo -e "  • Quantum Management: ${YELLOW}${MCP_QUANTUM_MANAGEMENT_URL}${NC}"
        echo ""
        echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
        exit 0
    fi

    attempt=$((attempt + 1))
    sleep $SLEEP_INTERVAL
done

echo ""
echo ""
echo -e "${RED}✗ Timeout: N8N did not become reachable after $((MAX_ATTEMPTS * SLEEP_INTERVAL)) seconds.${NC}"
echo -e "${YELLOW}Please check the VM status and cloud-init logs:${NC}"
echo -e "  SSH: $(terraform output -raw ssh_command 2>/dev/null || echo 'N/A')"
echo -e "  Check logs: sudo cat /var/log/cloud-init-output.log"
exit 1
