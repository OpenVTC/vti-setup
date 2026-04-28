#!/bin/bash

# Nginx HTTPS Proxy Setup Script
# Usage: curl -sSL https://raw.githubusercontent.com/ic3software/vti-setup/main/scripts/ubuntu-server-setup.sh | bash -s -- <domain> [email]
# Example: curl -sSL https://raw.githubusercontent.com/ic3software/vti-setup/main/scripts/ubuntu-server-setup.sh | bash -s -- example.com
# Example: curl -sSL https://raw.githubusercontent.com/ic3software/vti-setup/main/scripts/ubuntu-server-setup.sh | bash -s -- example.com admin@example.com
# Domain is required. Email is optional (used for Let's Encrypt expiry notifications).
# This script sets up Nginx reverse proxy configurations for VTA services.

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

usage() {
  echo "Usage: curl -sSL https://raw.githubusercontent.com/ic3software/vti-setup/main/scripts/ubuntu-server-setup.sh | bash -s -- <domain> [email]"
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

echo -e "${GREEN}=== VTA-C / VTA-P Nginx Setup ===${NC}"
echo -e "${GREEN}Domain: $DOMAIN${NC}"
if [ -n "$EMAIL" ]; then
  echo -e "${GREEN}Email: $EMAIL${NC}"
else
  echo -e "${YELLOW}Email: (not provided — certbot will register without email)${NC}"
fi
echo ""

# -----------------------------------------------------------------------------
echo -e "${GREEN}>>> Step 1/11: Update system <<<${NC}"
# -----------------------------------------------------------------------------
sudo apt update && sudo apt upgrade -y

# -----------------------------------------------------------------------------
echo -e "${GREEN}>>> Step 2/11: Install build and runtime dependencies <<<${NC}"
# -----------------------------------------------------------------------------
sudo apt -y install git curl build-essential pkg-config libssl-dev clang cmake ca-certificates libdbus-1-dev ufw

# -----------------------------------------------------------------------------
echo -e "${GREEN}>>> Step 3/11: Configure UFW firewall <<<${NC}"
# -----------------------------------------------------------------------------
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow 22/tcp
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw --force enable
sudo ufw status

# -----------------------------------------------------------------------------
echo -e "${GREEN}>>> Step 4/11: Install Rust <<<${NC}"
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
echo -e "${GREEN}>>> Step 5/11: Install Node.js (v22) <<<${NC}"
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
echo -e "${GREEN}>>> Step 6/11: Source .bashrc <<<${NC}"
# -----------------------------------------------------------------------------
# shellcheck disable=SC1090
[ -f "$HOME/.bashrc" ] && source "$HOME/.bashrc"

# -----------------------------------------------------------------------------
echo -e "${GREEN}>>> Step 7/11: Install Docker <<<${NC}"
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
echo -e "${GREEN}>>> Step 8/11: Install Nginx and Certbot <<<${NC}"
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
echo -e "${GREEN}>>> Step 9/11: Create Nginx configs and enable sites <<<${NC}"
# -----------------------------------------------------------------------------
echo -e "${YELLOW}Creating Nginx configuration files...${NC}"

VTA_C_CONFIG=$(cat <<EOF
server {
    listen 80;
    server_name vta-c.${DOMAIN};

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

VTA_P_CONFIG=$(cat <<EOF
server {
    listen 80;
    server_name vta-p.${DOMAIN};

    location / {
        proxy_pass http://127.0.0.1:8101;
        proxy_set_header Host \$host;
        proxy_set_header X-Forwarded-Proto \$http_x_forwarded_proto;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Host \$host;
    }
}
EOF
)

WEBVH_CONFIG=$(cat <<EOF
server {
    listen 80;
    server_name webvh.${DOMAIN};

    location / {
        proxy_pass http://127.0.0.1:8000;
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

sudo tee /etc/nginx/sites-available/vta-c.conf > /dev/null <<EOF
${VTA_C_CONFIG}
EOF

sudo tee /etc/nginx/sites-available/vta-p.conf > /dev/null <<EOF
${VTA_P_CONFIG}
EOF

sudo tee /etc/nginx/sites-available/webvh.conf > /dev/null <<EOF
${WEBVH_CONFIG}
EOF

sudo tee /etc/nginx/sites-available/mediator.conf > /dev/null <<EOF
${MEDIATOR_CONFIG}
EOF

echo -e "${YELLOW}Enabling sites...${NC}"
sudo ln -sf /etc/nginx/sites-available/vta-c.conf /etc/nginx/sites-enabled/
sudo ln -sf /etc/nginx/sites-available/vta-p.conf /etc/nginx/sites-enabled/
sudo ln -sf /etc/nginx/sites-available/webvh.conf /etc/nginx/sites-enabled/
sudo ln -sf /etc/nginx/sites-available/mediator.conf /etc/nginx/sites-enabled/

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
echo -e "${GREEN}>>> Step 10/11: Obtain SSL certificates (Certbot) <<<${NC}"
# -----------------------------------------------------------------------------

if [ -n "$EMAIL" ]; then
  if sudo certbot --nginx \
    -d "vta-c.${DOMAIN}" -d "vta-p.${DOMAIN}" -d "webvh.${DOMAIN}" -d "mediator.${DOMAIN}" \
    --email "$EMAIL" --agree-tos --non-interactive; then
    echo -e "${GREEN}Certbot completed successfully.${NC}"
  else
    echo -e "${YELLOW}Certbot did not complete (e.g. DNS not ready).${NC}"
    echo -e "You can run manually later:"
    echo "  sudo certbot --nginx -d vta-c.${DOMAIN} -d vta-p.${DOMAIN} -d webvh.${DOMAIN} -d mediator.${DOMAIN} --email $EMAIL --agree-tos"
  fi
else
  if sudo certbot --nginx \
    -d "vta-c.${DOMAIN}" -d "vta-p.${DOMAIN}" -d "webvh.${DOMAIN}" -d "mediator.${DOMAIN}" \
    --register-unsafely-without-email --agree-tos --non-interactive; then
    echo -e "${GREEN}Certbot completed successfully.${NC}"
  else
    echo -e "${YELLOW}Certbot did not complete (e.g. DNS not ready).${NC}"
    echo -e "You can run manually later:"
    echo "  sudo certbot --nginx -d vta-c.${DOMAIN} -d vta-p.${DOMAIN} -d webvh.${DOMAIN} -d mediator.${DOMAIN} --register-unsafely-without-email --agree-tos"
  fi
fi

# -----------------------------------------------------------------------------
echo -e "${GREEN}>>> Step 11/11: Verify URLs <<<${NC}"
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

check_url "https://vta-c.${DOMAIN}"
check_url "https://vta-p.${DOMAIN}"
check_url "https://webvh.${DOMAIN}"
check_url "https://mediator.${DOMAIN}"

echo ""
echo -e "${GREEN}Setup complete.${NC}"
echo -e "  Sites:"
echo -e "    - https://vta-c.${DOMAIN}    → localhost:8100"
echo -e "    - https://vta-p.${DOMAIN}    → localhost:8101"
echo -e "    - https://webvh.${DOMAIN}    → localhost:8000"
echo -e "    - https://mediator.${DOMAIN} → localhost:7037"
echo ""
echo -e "${YELLOW}NOTE: Rust/Cargo were installed in this script's subshell.${NC}"
echo -e "${YELLOW}To use 'cargo' in your current shell, run:${NC}"
echo -e "    source \$HOME/.cargo/env"
echo -e "${YELLOW}Or start a new login shell (logout and back in).${NC}"
