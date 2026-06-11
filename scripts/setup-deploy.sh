#!/bin/bash

# Deploy-stream setup script for the VTI stack — stage 2.
#
# Run as the non-root 'vti' user (created by bootstrap-user.sh).
#
# Creates dedicated system users for each service (vta-svc, mediator-svc,
# dids-svc, vtc-svc, plus witness/control/watcher in --standalone), installs
# systemd unit files with sandboxing, sets up the vti-exchange group for
# cross-service file handoffs, configures nginx + certbot, and obtains TLS
# certificates. No build toolchain, no Docker — this is the lean, hardened
# install path. Pre-built binaries only.
#
# Usage: curl -sSL https://raw.githubusercontent.com/OpenVTC/vti-setup/main/scripts/setup-deploy.sh | bash -s -- [--standalone] <domain> <email>
# Example: ... | bash -s -- example.com admin@example.com
# Example: ... | bash -s -- --standalone example.com admin@example.com
#
# Domain AND email are required. The deploy stream needs certbot expiry
# notifications, so the unsafe-no-email branch is not offered here.
#
# --standalone configures DID Hosting in standalone mode (separate control,
# server, witness, and watcher services on separate ports).

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

OPERATOR_USER="vti"
EXCHANGE_GROUP="vti-exchange"
EXCHANGE_DIR="/var/lib/${EXCHANGE_GROUP}"

usage() {
  echo "Usage: curl -sSL https://raw.githubusercontent.com/OpenVTC/vti-setup/main/scripts/setup-deploy.sh | bash -s -- [--standalone] <domain> <email>"
  echo "Example: ... | bash -s -- example.com admin@example.com"
  echo "Example: ... | bash -s -- --standalone example.com admin@example.com"
  echo ""
  echo "Domain AND email are required."
  echo "--standalone: configure DID Hosting in standalone mode (separate control, server, witness, and watcher services)."
  exit 1
}

DOMAIN=""
EMAIL=""
STANDALONE=false

while [[ $# -gt 0 ]]; do
  case "$1" in
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

if [ -z "$DOMAIN" ] || [ -z "$EMAIL" ]; then
  echo -e "${RED}Error: both domain and email are required.${NC}"
  usage
fi

if [ "$EUID" -eq 0 ]; then
  echo -e "${RED}Error: do not run this script as root.${NC}"
  echo -e "${RED}Run scripts/bootstrap-user.sh first (as root) to create the '${OPERATOR_USER}' user,${NC}"
  echo -e "${RED}then reconnect as ${OPERATOR_USER} and re-run this script.${NC}"
  exit 1
fi

if [ "$(id -un)" != "$OPERATOR_USER" ]; then
  echo -e "${YELLOW}Warning: you are running as '$(id -un)', not '${OPERATOR_USER}'.${NC}"
  echo -e "${YELLOW}The vti-exchange group will be set up for '${OPERATOR_USER}', not for the current user.${NC}"
  echo -e "${YELLOW}Reconnect as '${OPERATOR_USER}' if you want the standard layout.${NC}"
fi

echo -e "${GREEN}=== VTI Stack Deploy Setup ===${NC}"
echo -e "${GREEN}Domain: $DOMAIN${NC}"
echo -e "${GREEN}Email: $EMAIL${NC}"
if $STANDALONE; then
  echo -e "${GREEN}Mode: standalone DID Hosting${NC}"
else
  echo -e "${GREEN}Mode: standard${NC}"
fi
echo ""

# Step counter
TOTAL_STEPS=9
STEP=0
banner() {
  STEP=$((STEP + 1))
  echo ""
  echo -e "${GREEN}>>> Step ${STEP}/${TOTAL_STEPS}: $1 <<<${NC}"
}

# Service-binary mapping. Keys are svc short names (matching the user names
# minus the -svc suffix). Standard mode: vta, mediator, vtc, dids. Standalone
# mode adds witness, control, watcher AND swaps the dids binary.
BASE_SVCS=(vta mediator vtc dids)
STANDALONE_SVCS=(witness control watcher)

# Returns the /usr/local/bin path for a given svc short name.
binary_for() {
  case "$1" in
    vta)      echo "/usr/local/bin/vta" ;;
    mediator) echo "/usr/local/bin/mediator" ;;
    vtc)      echo "/usr/local/bin/vtc" ;;
    dids)
      if $STANDALONE; then echo "/usr/local/bin/did-hosting-server"
      else echo "/usr/local/bin/did-hosting-daemon"
      fi
      ;;
    witness)  echo "/usr/local/bin/webvh-witness" ;;
    control)  echo "/usr/local/bin/did-hosting-control" ;;
    watcher)  echo "/usr/local/bin/webvh-watcher" ;;
    *)        echo "unknown" ;;
  esac
}

# Returns a human-readable description.
desc_for() {
  case "$1" in
    vta)      echo "Verifiable Trust Agent" ;;
    mediator) echo "DIDComm Messaging Mediator" ;;
    vtc)      echo "Verifiable Trust Community" ;;
    dids)
      if $STANDALONE; then echo "DID Hosting Server (standalone)"
      else echo "DID Hosting Daemon (integrated)"
      fi
      ;;
    witness)  echo "WebVH Witness" ;;
    control)  echo "DID Hosting Control" ;;
    watcher)  echo "WebVH Watcher" ;;
    *)        echo "Unknown service" ;;
  esac
}

# Returns the local port the binary listens on.
port_for() {
  case "$1" in
    vta)      echo "8100" ;;
    mediator) echo "7037" ;;
    vtc)      echo "8200" ;;
    dids)
      if $STANDALONE; then echo "8530"
      else echo "8534"
      fi
      ;;
    witness)  echo "8531" ;;
    control)  echo "8532" ;;
    watcher)  echo "8533" ;;
    *)        echo "0" ;;
  esac
}

# Composes the list of enabled svc short names for this run.
enabled_svcs() {
  local svc
  for svc in "${BASE_SVCS[@]}"; do echo "$svc"; done
  if $STANDALONE; then
    for svc in "${STANDALONE_SVCS[@]}"; do echo "$svc"; done
  fi
}

# -----------------------------------------------------------------------------
banner "Update system"
# -----------------------------------------------------------------------------
sudo apt update && sudo apt upgrade -y

# -----------------------------------------------------------------------------
banner "Install runtime dependencies"
# -----------------------------------------------------------------------------
# No build toolchain. No Docker. The deploy stream uses pre-built binaries only.
# valkey-server backs the mediator's queue + persistent state (storage = redis).
sudo apt -y install ufw ca-certificates curl valkey-server

# -----------------------------------------------------------------------------
banner "Enable Valkey AOF persistence"
# -----------------------------------------------------------------------------
# Default RDB-only snapshots can lose ~minutes of mediator state on crash.
# AOF replays at boot for ~1s loss tolerance — appropriate for a deploy that
# carries real account/ACL state. Idempotent: matches the package default
# exactly, so the sed is a no-op once it's already been flipped.
if ! sudo test -f /etc/valkey/valkey.conf; then
  echo -e "${RED}Expected /etc/valkey/valkey.conf — valkey-server install may have failed.${NC}"
  exit 1
fi
if sudo grep -q '^appendonly yes' /etc/valkey/valkey.conf; then
  echo -e "${GREEN}Valkey AOF already enabled.${NC}"
else
  sudo sed -i 's/^appendonly no$/appendonly yes/' /etc/valkey/valkey.conf
  echo -e "${GREEN}Valkey AOF enabled — bouncing daemon to pick up config.${NC}"
fi
sudo systemctl is-active --quiet valkey-server || sudo systemctl enable --now valkey-server
sudo systemctl restart valkey-server
ss -tlnp 'sport = :6379' 2>/dev/null | grep -q 127.0.0.1 \
  && echo -e "${GREEN}Valkey listening on 127.0.0.1:6379.${NC}" \
  || echo -e "${YELLOW}Valkey not on 127.0.0.1:6379 — check /etc/valkey/valkey.conf bind setting.${NC}"

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

# -----------------------------------------------------------------------------
banner "Create per-service users, data dirs, and vti-exchange group"
# -----------------------------------------------------------------------------
for svc in $(enabled_svcs); do
  user="${svc}-svc"
  if id -u "$user" >/dev/null 2>&1; then
    echo -e "${YELLOW}User '${user}' already exists, skipping creation.${NC}"
  else
    sudo useradd -r -s /usr/sbin/nologin -M -d "/var/lib/${user}" "$user"
  fi
  sudo install -d -m 0750 -o "$user" -g "$user" "/var/lib/${user}"
done

# Shared group for cross-service handoffs (bundle.armor, bootstrap-request.json).
sudo groupadd -f "$EXCHANGE_GROUP"
sudo usermod -aG "$EXCHANGE_GROUP" "$OPERATOR_USER"
for svc in $(enabled_svcs); do
  sudo usermod -aG "$EXCHANGE_GROUP" "${svc}-svc"
done
# mode 2770 = SGID so dropped files inherit the vti-exchange group.
sudo install -d -m 2770 -o "$OPERATOR_USER" -g "$EXCHANGE_GROUP" "$EXCHANGE_DIR"

# -----------------------------------------------------------------------------
banner "Install systemd unit files"
# -----------------------------------------------------------------------------
install_unit() {
  local svc="$1"
  local user="${svc}-svc"
  local binary
  local desc
  binary=$(binary_for "$svc")
  desc=$(desc_for "$svc")
  # mediator-svc reads + writes Valkey for queue and persistent state — order
  # after it and refuse to start without it. The other services don't touch
  # Valkey, so the dep is mediator-only.
  local extra_unit_deps=""
  if [ "$svc" = "mediator" ]; then
    extra_unit_deps=$'\nAfter=valkey-server.service\nRequires=valkey-server.service'
  fi
  sudo tee "/etc/systemd/system/${user}.service" > /dev/null <<EOF
[Unit]
Description=${desc}
After=network-online.target
Wants=network-online.target${extra_unit_deps}

[Service]
Type=simple
User=${user}
Group=${user}
WorkingDirectory=/var/lib/${user}
ExecStart=${binary}
Restart=on-failure
RestartSec=5

NoNewPrivileges=true
ProtectSystem=strict
ProtectHome=true
PrivateTmp=true
PrivateDevices=true
ProtectKernelTunables=true
ProtectKernelModules=true
ProtectControlGroups=true
RestrictAddressFamilies=AF_UNIX AF_INET AF_INET6
RestrictNamespaces=true
LockPersonality=true
SystemCallArchitectures=native
ReadWritePaths=/var/lib/${user} ${EXCHANGE_DIR}

StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF
}

for svc in $(enabled_svcs); do
  install_unit "$svc"
done
sudo systemctl daemon-reload
echo -e "${GREEN}Unit files installed. Services are not yet enabled — provision them first per sysop/deploy/03-provisioning.md.${NC}"

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

write_vhost() {
  local svc="$1"
  local subdomain="$2"
  local port
  port=$(port_for "$svc")
  local conf
  if [ "$svc" = "mediator" ]; then
    conf=$(cat <<EOF
server {
    listen 80;
    server_name ${subdomain}.${DOMAIN};

    location /mediator/v1/ws {
        proxy_pass http://127.0.0.1:${port};
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_read_timeout 3600s;
    }

    location / {
        proxy_pass http://127.0.0.1:${port};
        proxy_set_header Host \$host;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Host \$host;
    }
}
EOF
)
  else
    conf=$(cat <<EOF
server {
    listen 80;
    server_name ${subdomain}.${DOMAIN};

    location / {
        proxy_pass http://127.0.0.1:${port};
        proxy_set_header Host \$host;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Host \$host;
    }
}
EOF
)
  fi
  sudo tee "/etc/nginx/sites-available/${subdomain}.conf" > /dev/null <<EOF
${conf}
EOF
  sudo ln -sf "/etc/nginx/sites-available/${subdomain}.conf" /etc/nginx/sites-enabled/
}

write_vhost mediator mediator
write_vhost vta      vta
write_vhost vtc      vtc
write_vhost dids     dids
if $STANDALONE; then
  write_vhost witness witness
  write_vhost control control
  write_vhost watcher watcher
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
CERTBOT_DOMAINS="-d mediator.${DOMAIN} -d vta.${DOMAIN} -d vtc.${DOMAIN} -d dids.${DOMAIN}"
if $STANDALONE; then
  CERTBOT_DOMAINS="$CERTBOT_DOMAINS -d witness.${DOMAIN} -d control.${DOMAIN} -d watcher.${DOMAIN}"
fi

if sudo certbot --nginx $CERTBOT_DOMAINS --email "$EMAIL" --agree-tos --non-interactive; then
  echo -e "${GREEN}Certbot completed successfully.${NC}"
else
  echo -e "${YELLOW}Certbot did not complete (e.g. DNS not ready).${NC}"
  echo -e "You can run manually later:"
  echo "  sudo certbot --nginx $CERTBOT_DOMAINS --email $EMAIL --agree-tos"
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
echo -e "${GREEN}Deploy setup complete.${NC}"
echo ""
echo -e "  Service users:"
for svc in $(enabled_svcs); do
  user="${svc}-svc"
  echo -e "    - ${user}  → /var/lib/${user}  → $(binary_for "$svc")  (port $(port_for "$svc"))"
done
echo ""
echo -e "  Exchange directory: ${EXCHANGE_DIR}  (mode 2770, group ${EXCHANGE_GROUP})"
echo ""
echo -e "  Sites:"
for svc in $(enabled_svcs); do
  echo -e "    - https://${svc}.${DOMAIN}"
done
echo ""
echo -e "${YELLOW}Next: provision each service per sysop/deploy/03-provisioning.md.${NC}"
echo -e "${YELLOW}  Per service, you will sudoedit /var/lib/<svc>-svc/<svc>-recipe.toml,${NC}"
echo -e "${YELLOW}  run 'sudo -u <svc>-svc <binary>-setup --from /var/lib/<svc>-svc/<svc>-recipe.toml',${NC}"
echo -e "${YELLOW}  then 'sudo systemctl enable --now <svc>-svc'.${NC}"
