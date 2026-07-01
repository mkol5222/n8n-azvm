#cloud-config
package_update: true
package_upgrade: true

packages:
  - apt-transport-https
  - ca-certificates
  - curl
  - gnupg
  - lsb-release

write_files:
  - path: /opt/n8n/.env
    permissions: '0644'
    content: |
      DOMAIN_NAME=${fqdn}
      SSL_EMAIL=${ssl_email}
      GENERIC_TIMEZONE=${timezone}
      N8N_BASIC_AUTH_ACTIVE=${n8n_basic_auth_active}
      N8N_BASIC_AUTH_USER=${n8n_basic_auth_user}
      N8N_BASIC_AUTH_PASSWORD=${n8n_basic_auth_password}
      N8N_ENCRYPTION_KEY=${n8n_encryption_key}
      N8N_OWNER_EMAIL=${n8n_owner_email}
      N8N_OWNER_FIRST_NAME=${n8n_owner_first_name}
      N8N_OWNER_LAST_NAME=${n8n_owner_last_name}

  - path: /opt/n8n/docker-compose.yml
    permissions: '0644'
    content: |
      services:
        traefik:
          image: traefik:latest
          restart: always
          command:
            - "--api=true"
            - "--api.insecure=true"
            - "--providers.docker=true"
            - "--providers.docker.exposedbydefault=false"
            - "--entrypoints.web.address=:80"
            - "--entrypoints.web.http.redirections.entryPoint.to=websecure"
            - "--entrypoints.web.http.redirections.entryPoint.scheme=https"
            - "--entrypoints.websecure.address=:443"
            - "--certificatesresolvers.mytlschallenge.acme.tlschallenge=true"
            - "--certificatesresolvers.mytlschallenge.acme.email=$${SSL_EMAIL}"
            - "--certificatesresolvers.mytlschallenge.acme.storage=/letsencrypt/acme.json"
          ports:
            - "80:80"
            - "443:443"
          volumes:
            - traefik_data:/letsencrypt
            - /var/run/docker.sock:/var/run/docker.sock:ro

        mcp-everything:
          image: node:20-alpine
          restart: always
          command: sh -c "npx -y @modelcontextprotocol/server-everything"
          environment:
            - PORT=5077
          expose:
            - "5077"
          healthcheck:
            test: ["CMD", "wget", "-q", "--spider", "http://localhost:5077/mcp"]
            interval: 30s
            timeout: 10s
            retries: 3

        mcp-management-logs:
          image: node:20-alpine
          restart: always
          command: sh -c "npx -y @chkp/management-logs-mcp"
          environment:
            - MCP_TRANSPORT_TYPE=http
            - MCP_TRANSPORT_PORT=5078
            - MANAGEMENT_HOST=${mcp_management_host}
            - USERNAME=${mcp_management_user}
            - PASSWORD=${mcp_management_password}
            - TELEMETRY_DISABLED=true
          expose:
            - "5078"
          healthcheck:
            test: ["CMD", "wget", "-q", "--spider", "http://localhost:5078/health"]
            interval: 30s
            timeout: 10s
            retries: 3

        mcp-quantum-management:
          image: node:20-alpine
          restart: always
          command: sh -c "npx -y @chkp/quantum-management-mcp"
          environment:
            - MCP_TRANSPORT_TYPE=http
            - MCP_TRANSPORT_PORT=5079
            - MANAGEMENT_HOST=${mcp_management_host}
            - USERNAME=${mcp_management_user}
            - PASSWORD=${mcp_management_password}
            - TELEMETRY_DISABLED=true
          expose:
            - "5079"
          healthcheck:
            test: ["CMD", "wget", "-q", "--spider", "http://localhost:5079/health"]
            interval: 30s
            timeout: 10s
            retries: 3

        n8n:
          image: docker.n8n.io/n8nio/n8n
          restart: always
          ports:
            - "127.0.0.1:5678:5678"
          labels:
            - traefik.enable=true
            - traefik.http.routers.n8n.rule=Host(`$${DOMAIN_NAME}`)
            - traefik.http.routers.n8n.tls=true
            - traefik.http.routers.n8n.entrypoints=websecure
            - traefik.http.routers.n8n.tls.certresolver=mytlschallenge
            - traefik.http.middlewares.n8n.headers.SSLRedirect=true
            - traefik.http.middlewares.n8n.headers.STSSeconds=315360000
            - traefik.http.middlewares.n8n.headers.browserXSSFilter=true
            - traefik.http.middlewares.n8n.headers.contentTypeNosniff=true
            - traefik.http.middlewares.n8n.headers.forceSTSHeader=true
            - traefik.http.middlewares.n8n.headers.SSLHost=$${DOMAIN_NAME}
            - traefik.http.middlewares.n8n.headers.STSIncludeSubdomains=true
            - traefik.http.middlewares.n8n.headers.STSPreload=true
            - traefik.http.routers.n8n.middlewares=n8n@docker
          environment:
            - N8N_HOST=$${DOMAIN_NAME}
            - N8N_PORT=5678
            - N8N_PROTOCOL=https
            - NODE_ENV=production
            - WEBHOOK_URL=https://$${DOMAIN_NAME}/
            - GENERIC_TIMEZONE=$${GENERIC_TIMEZONE}
            - N8N_BASIC_AUTH_ACTIVE=$${N8N_BASIC_AUTH_ACTIVE:-false}
            - N8N_BASIC_AUTH_USER=$${N8N_BASIC_AUTH_USER:-}
            - N8N_BASIC_AUTH_PASSWORD=$${N8N_BASIC_AUTH_PASSWORD:-}
            - N8N_ENCRYPTION_KEY=$${N8N_ENCRYPTION_KEY}
            - N8N_INSTANCE_OWNER_MANAGED_BY_ENV=true
            - N8N_INSTANCE_OWNER_EMAIL=$${N8N_OWNER_EMAIL}
            - N8N_INSTANCE_OWNER_FIRST_NAME=$${N8N_OWNER_FIRST_NAME}
            - N8N_INSTANCE_OWNER_LAST_NAME=$${N8N_OWNER_LAST_NAME}
            - N8N_INSTANCE_OWNER_PASSWORD_HASH=${n8n_owner_password_hash_escaped}
          volumes:
            - n8n_data:/home/node/.n8n
            - /opt/n8n/local-files:/files

      volumes:
        traefik_data:
        n8n_data:

runcmd:
  - curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
  - echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
  - apt-get update
  - apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
  - systemctl enable docker
  - systemctl start docker
  - usermod -aG docker ${admin_username}
  - mkdir -p /opt/n8n/local-files
  - chown -R 1000:1000 /opt/n8n/local-files
  - cd /opt/n8n && docker compose up -d
