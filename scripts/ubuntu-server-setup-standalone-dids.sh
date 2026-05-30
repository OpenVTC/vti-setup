#!/bin/bash

# Nginx HTTPS Proxy Setup Script
# Usage: curl -sSL https://raw.githubusercontent.com/OpenVTC/vti-setup/main/scripts/ubuntu-server-setup.sh | bash -s -- <domain> [email]
# Example: curl -sSL https://raw.githubusercontent.com/OpenVTC/vti-setup/main/scripts/ubuntu-server-setup.sh | bash -s -- example.com
# Example: curl -sSL https://raw.githubusercontent.com/OpenVTC/vti-setup/main/scripts/ubuntu-server-setup.sh | bash -s -- example.com admin@example.com
# Domain is required. Email is optional (used for Let's Encrypt expiry notifications).
# This script sets up Nginx reverse proxy configurations for VTA services.

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

usage() {
  echo "Usage: curl -sSL https://raw.githubusercontent.com/OpenVTC/vti-setup/main/scripts/ubuntu-server-setup.sh | bash -s -- <domain> [email]"
  echo "Example: ... | bash -s -- example.com"
  echo "Example: ... | bash -s -- example.com admin@example.com"
  echo ""
  echo "Domain is required. Email is optional (used for Let's Encrypt certificate expiry notifications)."
  exit 1
}

DOMAIN="${1:-}"
EMAIL="${2:-}"

if [ -z "$DOMAIN" ]; then
  echo -e "${RED}Error: domain is required.${NC}"
  usage
fi

echo -e "${GREEN}=== VTI Stack Nginx Setup ===${NC}"
echo -e "${GREEN}Domain: $DOMAIN${NC}"
if [ -n "$EMAIL" ]; then
  echo -e "${GREEN}Email: $EMAIL${NC}"
else
  echo -e "${YELLOW}Email: (not provided — certbot will register without email)${NC}"
fi
echo ""

# -----------------------------------------------------------------------------
echo -e "${GREEN}>>> Step 1/10: Update system <<<${NC}"
# -----------------------------------------------------------------------------
sudo apt update && sudo apt upgrade -y

# -----------------------------------------------------------------------------
echo -e "${GREEN}>>> Step 2/10: Install build and runtime dependencies <<<${NC}"
# -----------------------------------------------------------------------------
sudo apt -y install git curl build-essential pkg-config libssl-dev clang cmake ca-certificates libdbus-1-dev ufw

# -----------------------------------------------------------------------------
echo -e "${GREEN}>>> Step 3/10: Configure UFW firewall <<<${NC}"
# -----------------------------------------------------------------------------
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow 22/tcp
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw --force enable
sudo ufw status

# -----------------------------------------------------------------------------
echo -e "${GREEN}>>> Step 4/10: Install Rust <<<${NC}"
# -----------------------------------------------------------------------------
if command -v rustc &>/dev/null; then
  echo -e "${GREEN}Rust already installed: $(rustc --version)${NC}"
else
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
  source "$HOME/.cargo/env"
fi
rustc --version
cargo --version

# -----------------------------------------------------------------------------
echo -e "${GREEN}>>> Step 5/10: Install Node.js (v22) <<<${NC}"
# -----------------------------------------------------------------------------
if command -v node &>/dev/null && [ "$(node -v | cut -d. -f1 | tr -d 'v')" -ge 22 ] 2>/dev/null; then
  echo -e "${GREEN}Node.js already installed: $(node -v)${NC}"
else
  curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -
  sudo apt install -y nodejs
fi
node -v
npm -v

# -----------------------------------------------------------------------------
echo -e "${GREEN}>>> Step 6/10: Install Docker <<<${NC}"
# -----------------------------------------------------------------------------
if command -v docker &>/dev/null; then
  echo -e "${GREEN}Docker already installed: $(docker --version)${NC}"
else
  sudo apt-get install -y ca-certificates curl gnupg
  sudo install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  sudo chmod a+r /etc/apt/keyrings/docker.gpg
  echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
    $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
    sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
  sudo apt-get update
  sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
fi
sudo systemctl enable --now docker
sudo usermod -aG docker "$USER"
docker --version

# -----------------------------------------------------------------------------
echo -e "${GREEN}>>> Step 7/10: Install Nginx and Certbot <<<${NC}"
# -----------------------------------------------------------------------------
sudo apt -y install nginx
sudo systemctl enable --now nginx
if command -v certbot &>/dev/null; then
  echo -e "${GREEN}Certbot already installed.${NC}"
else
  sudo snap install --classic certbot
  sudo ln -sf /snap/bin/certbot /usr/bin/certbot
fi

# -----------------------------------------------------------------------------
echo -e "${GREEN}>>> Step 8/10: Create Nginx configs and enable sites <<<${NC}"
# -----------------------------------------------------------------------------
echo -e "${YELLOW}Creating Nginx configuration files...${NC}"

VTC_CONFIG=$(cat <<EOF
server {
    listen 80;
    server_name vtc.${DOMAIN};

    location / {
        proxy_pass http://127.0.0.1:8200;
        proxy_set_header Host \$host;
        proxy_set_header X-Forwarded-Proto \$http_x_forwarded_proto;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Host \$host;
    }
}
EOF
)

VTA_CONFIG=$(cat <<EOF
server {
    listen 80;
    server_name vta.${DOMAIN};

    location / {
        proxy_pass http://127.0.0.1:8100;
        proxy_set_header Host \$host;
        proxy_set_header X-Forwarded-Proto \$http_x_forwarded_proto;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Host \$host;
    }
}
EOF
)

MEDIATOR_CONFIG=$(cat <<EOF
server {
    listen 80;
    server_name mediator.${DOMAIN};

    location /mediator/v1/ws {
        proxy_pass http://127.0.0.1:7037;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_read_timeout 3600s;
    }

    location / {
        proxy_pass http://127.0.0.1:7037;
        proxy_set_header Host \$host;
        proxy_set_header X-Forwarded-Proto \$http_x_forwarded_proto;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Host \$host;
    }
}
EOF
)

DID_HOSTING_CONFIG=$(cat <<EOF
server {
    listen 80;
    server_name dids.${DOMAIN};

    location / {
        proxy_pass http://127.0.0.1:8530;
        proxy_set_header Host \$host;
        proxy_set_header X-Forwarded-Proto \$http_x_forwarded_proto;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Host \$host;
    }
}
EOF
)

WITNESS_CONFIG=$(cat <<EOF
server {
    listen 80;
    server_name witness.${DOMAIN};

    location / {
        proxy_pass http://127.0.0.1:8531;
        proxy_set_header Host \$host;
        proxy_set_header X-Forwarded-Proto \$http_x_forwarded_proto;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Host \$host;
    }
}
EOF
)

WATCHER_CONFIG=$(cat <<EOF
server {
    listen 80;
    server_name watcher.${DOMAIN};

    location / {
        proxy_pass http://127.0.0.1:8533;
        proxy_set_header Host \$host;
        proxy_set_header X-Forwarded-Proto \$http_x_forwarded_proto;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Host \$host;
    }
}
EOF
)

sudo tee /etc/nginx/sites-available/vtc.conf > /dev/null <<EOF
${VTC_CONFIG}
EOF

sudo tee /etc/nginx/sites-available/vta.conf > /dev/null <<EOF
${VTA_CONFIG}
EOF

sudo tee /etc/nginx/sites-available/mediator.conf > /dev/null <<EOF
${MEDIATOR_CONFIG}
EOF

sudo tee /etc/nginx/sites-available/dids.conf > /dev/null <<EOF
${DID_HOSTING_CONFIG}
EOF

sudo tee /etc/nginx/sites-available/witness.conf > /dev/null <<EOF
${WITNESS_CONFIG}
EOF

sudo tee /etc/nginx/sites-available/watcher.conf > /dev/null <<EOF
${WATCHER_CONFIG}
EOF

echo -e "${YELLOW}Enabling sites...${NC}"
sudo ln -sf /etc/nginx/sites-available/vtc.conf /etc/nginx/sites-enabled/
sudo ln -sf /etc/nginx/sites-available/vta.conf /etc/nginx/sites-enabled/
sudo ln -sf /etc/nginx/sites-available/mediator.conf /etc/nginx/sites-enabled/
sudo ln -sf /etc/nginx/sites-available/dids.conf /etc/nginx/sites-enabled/
sudo ln -sf /etc/nginx/sites-available/witness.conf /etc/nginx/sites-enabled/
sudo ln -sf /etc/nginx/sites-available/watcher.conf /etc/nginx/sites-enabled/

echo -e "${YELLOW}Testing Nginx configuration...${NC}"
if sudo nginx -t; then
  echo -e "${GREEN}Nginx config test passed.${NC}"
else
  echo -e "${RED}Nginx config test failed. Please check your setup.${NC}"
  exit 1
fi

echo -e "${YELLOW}Reloading Nginx...${NC}"
sudo systemctl reload nginx || sudo service nginx reload

# -----------------------------------------------------------------------------
echo -e "${GREEN}>>> Step 9/10: Obtain SSL certificates (Certbot) <<<${NC}"
# -----------------------------------------------------------------------------

if [ -n "$EMAIL" ]; then
  if sudo certbot --nginx \
    -d "vtc.${DOMAIN}" -d "vta.${DOMAIN}" -d "mediator.${DOMAIN}" \
    -d "dids.${DOMAIN}" -d "witness.${DOMAIN}" -d "watcher.${DOMAIN}" \
    --email "$EMAIL" --agree-tos --non-interactive; then
    echo -e "${GREEN}Certbot completed successfully.${NC}"
  else
    echo -e "${YELLOW}Certbot did not complete (e.g. DNS not ready).${NC}"
    echo -e "You can run manually later:"
    echo "  sudo certbot --nginx -d vtc.${DOMAIN} -d vta.${DOMAIN} -d mediator.${DOMAIN} -d did.${DOMAIN} -d witness.${DOMAIN} -d watcher.${DOMAIN} --email $EMAIL --agree-tos"
  fi
else
  if sudo certbot --nginx \
    -d "vtc.${DOMAIN}" -d "vta.${DOMAIN}" -d "mediator.${DOMAIN}" \
    -d "dids.${DOMAIN}" -d "witness.${DOMAIN}" -d "watcher.${DOMAIN}" \
    --register-unsafely-without-email --agree-tos --non-interactive; then
    echo -e "${GREEN}Certbot completed successfully.${NC}"
  else
    echo -e "${YELLOW}Certbot did not complete (e.g. DNS not ready).${NC}"
    echo -e "You can run manually later:"
    echo "  sudo certbot --nginx -d vtc.${DOMAIN} -d vta.${DOMAIN} -d mediator.${DOMAIN} -d did.${DOMAIN} -d witness.${DOMAIN} -d watcher.${DOMAIN} --register-unsafely-without-email --agree-tos"
  fi
fi

# -----------------------------------------------------------------------------
echo -e "${GREEN}>>> Step 10/10: Verify URLs <<<${NC}"
# -----------------------------------------------------------------------------
echo ""

check_url() {
  local url="$1"
  local code
  code=$(curl -sS -o /dev/null -w "%{http_code}" --connect-timeout 5 "$url" 2>/dev/null || echo "000")
  if [ "$code" = "502" ]; then
    echo -e "  ${GREEN}$url → 502 (backend not running yet) — URL set up successfully.${NC}"
  elif [ "$code" = "200" ]; then
    echo -e "  ${GREEN}$url → 200 OK — URL set up successfully.${NC}"
  else
    echo -e "  ${YELLOW}$url → HTTP $code${NC}"
  fi
}

check_url "https://vtc.${DOMAIN}"
check_url "https://vta.${DOMAIN}"
check_url "https://mediator.${DOMAIN}"
check_url "https://dids.${DOMAIN}"
check_url "https://witness.${DOMAIN}"
check_url "https://watcher.${DOMAIN}"

echo ""
echo -e "${GREEN}Setup complete.${NC}"
echo -e "  Sites:"
echo -e "    - https://vtc.${DOMAIN}      → localhost:8200"
echo -e "    - https://vta.${DOMAIN}      → localhost:8100"
echo -e "    - https://mediator.${DOMAIN} → localhost:7037"
echo -e "    - https://dids.${DOMAIN}      → localhost:8530"
echo -e "    - https://witness.${DOMAIN}  → localhost:8531"
echo -e "    - https://watcher.${DOMAIN}  → localhost:8533"
echo ""
echo -e "${YELLOW}NOTE: Rust/Cargo were installed in this script's subshell.${NC}"
echo -e "${YELLOW}To use 'cargo' in your current shell, run:${NC}"
echo -e "    source \$HOME/.cargo/env"
echo -e "${YELLOW}Or start a new login shell (logout and back in).${NC}"
