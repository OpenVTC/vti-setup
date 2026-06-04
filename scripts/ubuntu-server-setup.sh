#!/bin/bash

# Nginx HTTPS Proxy Setup Script — stage 2 of VTI server setup.
#
# Run as the non-root 'vti' user (created by scripts/bootstrap-user.sh).
#
# Usage: curl -sSL https://raw.githubusercontent.com/OpenVTC/vti-setup/main/scripts/ubuntu-server-setup.sh | bash -s -- [--dev] [--standalone] <domain> [email]
# Example: ... | bash -s -- example.com
# Example: ... | bash -s -- example.com admin@example.com
# Example: ... | bash -s -- --standalone example.com
# Example: ... | bash -s -- --dev example.com admin@example.com
#
# Domain is required. Email is optional (used for Let's Encrypt expiry notifications).
# --dev: also install Rust, Node.js, and the C/C++ build toolchain (for building binaries from source).
#        Default is the lean "live" install — nginx, certbot, ufw only.
# --standalone sets up separate DID Hosting control, witness, and watcher services on separate ports.
# This script sets up Nginx reverse proxy configurations for VTI services.

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

usage() {
  echo "Usage: curl -sSL https://raw.githubusercontent.com/OpenVTC/vti-setup/main/scripts/ubuntu-server-setup.sh | bash -s -- [--dev] [--standalone] <domain> [email]"
  echo "Example: ... | bash -s -- example.com"
  echo "Example: ... | bash -s -- example.com admin@example.com"
  echo "Example: ... | bash -s -- --standalone example.com"
  echo "Example: ... | bash -s -- --dev example.com admin@example.com"
  echo ""
  echo "Domain is required. Email is optional (used for Let's Encrypt certificate expiry notifications)."
  echo "--dev: also install Rust, Node.js, and the C/C++ build toolchain (for building binaries from source)."
  echo "       Default is the lean 'live' install — nginx, certbot, ufw only."
  echo "--standalone: configure DID Hosting in standalone mode (separate control, witness, and watcher services)."
  exit 1
}

DOMAIN=""
EMAIL=""
STANDALONE=false
DEV=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dev)
      DEV=true
      shift
      ;;
    --standalone)
      STANDALONE=true
      shift
      ;;
    *)
      if [ -z "$DOMAIN" ]; then
        DOMAIN="$1"
      elif [ -z "$EMAIL" ]; then
        EMAIL="$1"
      fi
      shift
      ;;
  esac
done

if [ -z "$DOMAIN" ]; then
  echo -e "${RED}Error: domain is required.${NC}"
  usage
fi

if [ "$EUID" -eq 0 ]; then
  echo -e "${RED}Error: do not run this script as root.${NC}"
  echo -e "${RED}Run scripts/bootstrap-user.sh first (as root) to create the 'vti' user,${NC}"
  echo -e "${RED}then reconnect as vti and re-run this script.${NC}"
  exit 1
fi

echo -e "${GREEN}=== VTI Stack Nginx Setup ===${NC}"
echo -e "${GREEN}Domain: $DOMAIN${NC}"
if [ -n "$EMAIL" ]; then
  echo -e "${GREEN}Email: $EMAIL${NC}"
else
  echo -e "${YELLOW}Email: (not provided — certbot will register without email)${NC}"
fi
if $DEV; then
  echo -e "${GREEN}Build: dev (install Rust, Node, build toolchain)${NC}"
else
  echo -e "${GREEN}Build: live (no compilers, no build toolchain)${NC}"
fi
if $STANDALONE; then
  echo -e "${GREEN}Mode: standalone DID Hosting${NC}"
else
  echo -e "${GREEN}Mode: standard${NC}"
fi
echo ""

# Step counter — total depends on whether --dev was passed.
if $DEV; then
  TOTAL_STEPS=9
else
  TOTAL_STEPS=7
fi
STEP=0
banner() {
  STEP=$((STEP + 1))
  echo ""
  echo -e "${GREEN}>>> Step ${STEP}/${TOTAL_STEPS}: $1 <<<${NC}"
}

# -----------------------------------------------------------------------------
banner "Update system"
# -----------------------------------------------------------------------------
sudo apt update && sudo apt upgrade -y

# -----------------------------------------------------------------------------
banner "Install runtime dependencies"
# -----------------------------------------------------------------------------
sudo apt -y install ufw ca-certificates curl
if $DEV; then
  echo -e "${YELLOW}Installing build toolchain (--dev)...${NC}"
  sudo apt -y install git build-essential pkg-config libssl-dev clang cmake libdbus-1-dev
fi

# -----------------------------------------------------------------------------
banner "Configure UFW firewall"
# -----------------------------------------------------------------------------
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow 22/tcp
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw --force enable
sudo ufw status

if $DEV; then
  # ---------------------------------------------------------------------------
  banner "Install Rust"
  # ---------------------------------------------------------------------------
  if command -v rustc &>/dev/null; then
    echo -e "${GREEN}Rust already installed: $(rustc --version)${NC}"
  else
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
    source "$HOME/.cargo/env"
  fi
  rustc --version
  cargo --version

  # ---------------------------------------------------------------------------
  banner "Install Node.js (v22)"
  # ---------------------------------------------------------------------------
  if command -v node &>/dev/null && [ "$(node -v | cut -d. -f1 | tr -d 'v')" -ge 22 ] 2>/dev/null; then
    echo -e "${GREEN}Node.js already installed: $(node -v)${NC}"
  else
    curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -
    sudo apt install -y nodejs
  fi
  node -v
  npm -v
fi

# -----------------------------------------------------------------------------
banner "Install Nginx and Certbot"
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
banner "Create Nginx configs and enable sites"
# -----------------------------------------------------------------------------
echo -e "${YELLOW}Creating Nginx configuration files...${NC}"

if $STANDALONE; then
  DIDS_PORT=8530
else
  DIDS_PORT=8534
fi

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
        proxy_set_header X-Forwarded-Proto \$scheme;
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
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Host \$host;
    }
}
EOF
)

VTC_CONFIG=$(cat <<EOF
server {
    listen 80;
    server_name vtc.${DOMAIN};

    location / {
        proxy_pass http://127.0.0.1:8200;
        proxy_set_header Host \$host;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Host \$host;
    }
}
EOF
)

DIDS_CONFIG=$(cat <<EOF
server {
    listen 80;
    server_name dids.${DOMAIN};

    location / {
        proxy_pass http://127.0.0.1:${DIDS_PORT};
        proxy_set_header Host \$host;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Host \$host;
    }
}
EOF
)

sudo tee /etc/nginx/sites-available/mediator.conf > /dev/null <<EOF
${MEDIATOR_CONFIG}
EOF

sudo tee /etc/nginx/sites-available/vta.conf > /dev/null <<EOF
${VTA_CONFIG}
EOF

sudo tee /etc/nginx/sites-available/vtc.conf > /dev/null <<EOF
${VTC_CONFIG}
EOF

sudo tee /etc/nginx/sites-available/dids.conf > /dev/null <<EOF
${DIDS_CONFIG}
EOF

echo -e "${YELLOW}Enabling sites...${NC}"
sudo ln -sf /etc/nginx/sites-available/mediator.conf /etc/nginx/sites-enabled/
sudo ln -sf /etc/nginx/sites-available/vta.conf /etc/nginx/sites-enabled/
sudo ln -sf /etc/nginx/sites-available/vtc.conf /etc/nginx/sites-enabled/
sudo ln -sf /etc/nginx/sites-available/dids.conf /etc/nginx/sites-enabled/

if $STANDALONE; then
  WITNESS_CONFIG=$(cat <<EOF
server {
    listen 80;
    server_name witness.${DOMAIN};

    location / {
        proxy_pass http://127.0.0.1:8531;
        proxy_set_header Host \$host;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Host \$host;
    }
}
EOF
)

  CONTROL_CONFIG=$(cat <<EOF
server {
    listen 80;
    server_name control.${DOMAIN};

    location / {
        proxy_pass http://127.0.0.1:8532;
        proxy_set_header Host \$host;
        proxy_set_header X-Forwarded-Proto \$scheme;
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
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Host \$host;
    }
}
EOF
)

  sudo tee /etc/nginx/sites-available/witness.conf > /dev/null <<EOF
${WITNESS_CONFIG}
EOF

  sudo tee /etc/nginx/sites-available/control.conf > /dev/null <<EOF
${CONTROL_CONFIG}
EOF

  sudo tee /etc/nginx/sites-available/watcher.conf > /dev/null <<EOF
${WATCHER_CONFIG}
EOF

  sudo ln -sf /etc/nginx/sites-available/witness.conf /etc/nginx/sites-enabled/
  sudo ln -sf /etc/nginx/sites-available/control.conf /etc/nginx/sites-enabled/
  sudo ln -sf /etc/nginx/sites-available/watcher.conf /etc/nginx/sites-enabled/
fi

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
banner "Obtain SSL certificates (Certbot)"
# -----------------------------------------------------------------------------

CERTBOT_DOMAINS="-d vtc.${DOMAIN} -d vta.${DOMAIN} -d dids.${DOMAIN} -d mediator.${DOMAIN}"
if $STANDALONE; then
  CERTBOT_DOMAINS="$CERTBOT_DOMAINS -d witness.${DOMAIN} -d control.${DOMAIN} -d watcher.${DOMAIN}"
fi

if [ -n "$EMAIL" ]; then
  if sudo certbot --nginx $CERTBOT_DOMAINS --email "$EMAIL" --agree-tos --non-interactive; then
    echo -e "${GREEN}Certbot completed successfully.${NC}"
  else
    echo -e "${YELLOW}Certbot did not complete (e.g. DNS not ready).${NC}"
    echo -e "You can run manually later:"
    echo "  sudo certbot --nginx $CERTBOT_DOMAINS --email $EMAIL --agree-tos"
  fi
else
  if sudo certbot --nginx $CERTBOT_DOMAINS --register-unsafely-without-email --agree-tos --non-interactive; then
    echo -e "${GREEN}Certbot completed successfully.${NC}"
  else
    echo -e "${YELLOW}Certbot did not complete (e.g. DNS not ready).${NC}"
    echo -e "You can run manually later:"
    echo "  sudo certbot --nginx $CERTBOT_DOMAINS --register-unsafely-without-email --agree-tos"
  fi
fi

# -----------------------------------------------------------------------------
banner "Verify URLs"
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

check_url "https://mediator.${DOMAIN}"
check_url "https://vta.${DOMAIN}"
check_url "https://vtc.${DOMAIN}"
check_url "https://dids.${DOMAIN}"
if $STANDALONE; then
  check_url "https://witness.${DOMAIN}"
  check_url "https://control.${DOMAIN}"
  check_url "https://watcher.${DOMAIN}"
fi

echo ""
echo -e "${GREEN}Setup complete.${NC}"
echo -e "  Sites:"
echo -e "    - https://mediator.${DOMAIN} → localhost:7037"
echo -e "    - https://vta.${DOMAIN}      → localhost:8100"
echo -e "    - https://vtc.${DOMAIN}      → localhost:8200"
echo -e "    - https://dids.${DOMAIN}     → localhost:${DIDS_PORT}"
if $STANDALONE; then
  echo -e "    - https://witness.${DOMAIN} → localhost:8531"
  echo -e "    - https://control.${DOMAIN} → localhost:8532"
  echo -e "    - https://watcher.${DOMAIN} → localhost:8533"
fi

if $DEV; then
  echo ""
  echo -e "${YELLOW}NOTE: Rust/Cargo were installed in this script's subshell.${NC}"
  echo -e "${YELLOW}To use 'cargo' in your current shell, run:${NC}"
  echo -e "    source \$HOME/.cargo/env"
  echo -e "${YELLOW}Or start a new login shell (logout and back in).${NC}"
fi
