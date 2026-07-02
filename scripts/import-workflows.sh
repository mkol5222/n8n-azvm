#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
WORKFLOWS_DIR="${PROJECT_DIR}/workflows"
COOKIE_FILE=$(mktemp)

cleanup() {
    rm -f "$COOKIE_FILE"
}
trap cleanup EXIT

echo -e "${CYAN}Fetching Terraform outputs...${NC}"

# Get outputs from Terraform
N8N_URL=$(terraform output -raw n8n_url 2>/dev/null) || {
    echo -e "${RED}Error: Failed to get n8n_url from Terraform outputs.${NC}"
    echo -e "${YELLOW}Make sure Terraform has been applied successfully.${NC}"
    exit 1
}

N8N_OWNER_EMAIL=$(terraform output -raw n8n_owner_email 2>/dev/null) || {
    echo -e "${RED}Error: Failed to get n8n_owner_email from Terraform outputs.${NC}"
    exit 1
}

N8N_OWNER_PASSWORD=$(terraform output -raw n8n_owner_password 2>/dev/null) || {
    echo -e "${RED}Error: Failed to get n8n_owner_password from Terraform outputs.${NC}"
    exit 1
}

echo -e "${CYAN}Logging into n8n at ${N8N_URL}...${NC}"

# Login to n8n and get session cookie
LOGIN_RESPONSE=$(curl -s -k -X POST "${N8N_URL}/rest/login" \
    -H "Content-Type: application/json" \
    -c "$COOKIE_FILE" \
    -d "{\"emailOrLdapLoginId\": \"${N8N_OWNER_EMAIL}\", \"password\": \"${N8N_OWNER_PASSWORD}\"}" \
    -w "\n%{http_code}")

HTTP_CODE=$(echo "$LOGIN_RESPONSE" | tail -1)
RESPONSE_BODY=$(echo "$LOGIN_RESPONSE" | sed '$d')

if [ "$HTTP_CODE" != "200" ]; then
    echo -e "${RED}Error: Failed to login to n8n (HTTP ${HTTP_CODE})${NC}"
    echo -e "${YELLOW}Response: ${RESPONSE_BODY}${NC}"
    exit 1
fi

echo -e "${GREEN}Successfully logged in${NC}"
echo ""

# Check if workflows directory exists and has JSON files
if [ ! -d "$WORKFLOWS_DIR" ]; then
    echo -e "${YELLOW}No workflows directory found at ${WORKFLOWS_DIR}${NC}"
    exit 0
fi

WORKFLOW_FILES=$(find "$WORKFLOWS_DIR" -name "*.json" -type f 2>/dev/null)
if [ -z "$WORKFLOW_FILES" ]; then
    echo -e "${YELLOW}No workflow JSON files found in ${WORKFLOWS_DIR}${NC}"
    exit 0
fi

echo -e "${CYAN}Importing workflows from ${WORKFLOWS_DIR}...${NC}"
echo ""

IMPORTED=0
FAILED=0

for WORKFLOW_FILE in $WORKFLOW_FILES; do
    WORKFLOW_NAME=$(basename "$WORKFLOW_FILE" .json)
    echo -ne "  Importing ${YELLOW}${WORKFLOW_NAME}${NC}... "

    # Import the workflow using n8n REST API (session-based auth)
    IMPORT_RESPONSE=$(curl -s -k -X POST "${N8N_URL}/rest/workflows" \
        -H "Content-Type: application/json" \
        -b "$COOKIE_FILE" \
        -d @"$WORKFLOW_FILE" \
        -w "\n%{http_code}")

    HTTP_CODE=$(echo "$IMPORT_RESPONSE" | tail -1)
    RESPONSE_BODY=$(echo "$IMPORT_RESPONSE" | sed '$d')

    if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "201" ]; then
        echo -e "${GREEN}OK${NC}"
        IMPORTED=$((IMPORTED + 1))
    else
        echo -e "${RED}FAILED (HTTP ${HTTP_CODE})${NC}"
        # Check if it's a duplicate error
        if echo "$RESPONSE_BODY" | grep -qi "already exists\|duplicate"; then
            echo -e "    ${YELLOW}(workflow may already exist)${NC}"
        fi
        FAILED=$((FAILED + 1))
    fi
done

echo ""
echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}                    WORKFLOW IMPORT COMPLETE                    ${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "  ${GREEN}Imported:${NC} ${IMPORTED}"
echo -e "  ${RED}Failed:${NC}   ${FAILED}"
echo ""
echo -e "  ${CYAN}Access your workflows at:${NC} ${N8N_URL}"
echo ""
echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
