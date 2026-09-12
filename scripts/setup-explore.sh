#!/bin/bash

# Explore-stream setup script for the VTI stack.
#
# Run once, as root, over the default SSH session of a fresh Ubuntu 26.04 host.
# Installs everything needed to play with the stack: build toolchain, Rust,
# Valkey, nginx, certbot, ufw. Wires up four nginx vhosts (mediator, vta, vtc,
# dids) and obtains Let's Encrypt certificates.
#
# Node.js is not installed here. Only the optional did-hosting-ui source build
# needs it, and sysop/explore/01-server-setup.md installs it at that step.
#
# Single DID Hosting topology only (integrated daemon). For the standalone
# topology, use the deploy stream instead.
#
# DO NOT use a box set up this way for real keys or production data. This
# stream is for learning and experimentation only.
#
# Get this script from a tagged GitHub release and check it before running it
# (sysop/explore/01-server-setup.md, Step 3). Never run a copy taken from the
# main branch.
#
# Usage: sudo bash setup-explore.sh <domain> [email]
# Example: sudo bash setup-explore.sh example.com
# Example: sudo bash setup-explore.sh example.com admin@example.com

set -euo pipefail

# Everything below is a definition until the call to main on the last line. If
# a download of this file is cut short, bash hits end-of-file inside a function
# body and runs nothing, rather than running whatever prefix arrived.

# Fallback Rust installer, used only when the apt archive has no rustup
# package. The URL is rustup's immutable per-version archive, and the hashes
# are the rustup-init.sha256 values published for that version (checked
# against the downloaded binaries when the pin was set). Bump all three
# together.
RUSTUP_VERSION=1.29.1
RUSTUP_INIT_SHA256_X86_64=dda7234360b7f578ca8b0ddcb80145646fa61a67c1720a5abc7051b35c9fcb71
RUSTUP_INIT_SHA256_AARCH64=15f6e4ce9f583b929c996c91562bad6d4454f3281de858b02cdfdef615fac433

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# No debconf dialog (keyboard layout, needrestart, changed config files) may
# open during the run: everything that installs packages has to take its
# defaults. The variables go on the command line because sudo's env_reset
# strips them from the exported environment.
apt_get() {
  sudo DEBIAN_FRONTEND=noninteractive NEEDRESTART_MODE=a apt-get -y \
    -o Dpkg::Options::=--force-confdef \
    -o Dpkg::Options::=--force-confold "$@"
}

usage() {
  echo "Usage: sudo bash setup-explore.sh <domain> [email]" >&2
  echo "Example: sudo bash setup-explore.sh example.com" >&2
  echo "Example: sudo bash setup-explore.sh example.com admin@example.com" >&2
  echo "" >&2
  echo "Domain is required. Email is optional (used for Let's Encrypt certificate expiry notifications)." >&2
  exit 1
}

die() {
  echo -e "${RED}Error: $*${NC}" >&2
  exit 1
}

# Both values end up in nginx server_name lines and certbot arguments, so
# accept only plain hostnames and addresses, before anything else runs.
validate_args() {
  local label='[A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?'
  local domain_re="^(${label}\\.)+[A-Za-z]{2,63}\$"
  local email_re="^[A-Za-z0-9._%+-]+@(${label}\\.)+[A-Za-z]{2,63}\$"

  if [ -z "$DOMAIN" ]; then
    echo -e "${RED}Error: domain is required.${NC}" >&2
    usage
  fi
  # "mediator." is the longest prefix added below; keep every name within 253.
  if [ "${#DOMAIN}" -gt 244 ] || ! [[ $DOMAIN =~ $domain_re ]]; then
    echo -e "${RED}Error: '$DOMAIN' is not a valid domain name.${NC}" >&2
    usage
  fi
  if [ -n "$EMAIL" ] && { [ "${#EMAIL}" -gt 254 ] || ! [[ $EMAIL =~ $email_re ]]; }; then
    echo -e "${RED}Error: '$EMAIL' is not a valid email address.${NC}" >&2
    usage
  fi
}

apt_has_candidate() {
  local candidate
  candidate=$(apt-cache policy "$1" 2>/dev/null | awk '/Candidate:/ {print $2}') || true
  [ -n "$candidate" ] && [ "$candidate" != "(none)" ]
}

install_rustup_init() {
  local triple expected workdir
  case "$(uname -m)" in
    x86_64) triple=x86_64-unknown-linux-gnu; expected=$RUSTUP_INIT_SHA256_X86_64 ;;
    aarch64 | arm64) triple=aarch64-unknown-linux-gnu; expected=$RUSTUP_INIT_SHA256_AARCH64 ;;
    *) die "no pinned rustup-init checksum for architecture $(uname -m)." ;;
  esac

  workdir=$(mktemp -d)
  curl --proto '=https' --tlsv1.2 -fsSL -o "$workdir/rustup-init" \
    "https://static.rust-lang.org/rustup/archive/${RUSTUP_VERSION}/${triple}/rustup-init"
  if ! printf '%s  %s\n' "$expected" "$workdir/rustup-init" | sha256sum -c --quiet -; then
    rm -rf "$workdir"
    die "rustup-init ${RUSTUP_VERSION} for ${triple} does not match its pinned SHA-256; refusing to run it."
  fi
  chmod 0755 "$workdir/rustup-init"
  "$workdir/rustup-init" -y --default-toolchain stable
  rm -rf "$workdir"
  # shellcheck source=/dev/null
  . "$HOME/.cargo/env"
}

# Ubuntu's rustup package puts cargo and rustc in /usr/bin, but `cargo install`
# still writes to ~/.cargo/bin. Put that on PATH for new login shells, as
# rustup-init does for its own install.
ensure_cargo_bin_on_path() {
  # shellcheck disable=SC2016 # expanded by the login shell, not here
  local line='export PATH="$HOME/.cargo/bin:$PATH"'
  local rc
  for rc in "$HOME/.profile" "$HOME/.bashrc"; do
    grep -qxF "$line" "$rc" 2>/dev/null || printf '\n%s\n' "$line" >>"$rc"
  done
  export PATH="$HOME/.cargo/bin:$PATH"
}

install_rust() {
  # Pick up a rustup-init install left by a previous run.
  if [ -f "$HOME/.cargo/env" ]; then
    # shellcheck source=/dev/null
    . "$HOME/.cargo/env"
  fi

  if rustc --version >/dev/null 2>&1; then
    echo -e "${GREEN}Rust already installed: $(rustc --version)${NC}"
  elif apt_has_candidate rustup; then
    # Signed Ubuntu archive package; rustup then installs the toolchain.
    apt_get install rustup
    rustup default stable
  else
    echo -e "${YELLOW}No rustup package in the apt archive; using pinned rustup-init ${RUSTUP_VERSION}.${NC}"
    install_rustup_init
  fi
  ensure_cargo_bin_on_path
  rustc --version
  cargo --version
}

write_nginx_configs() {
  sudo tee /etc/nginx/sites-available/mediator.conf >/dev/null <<EOF
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

  local name port
  for name in vta vtc dids; do
    case "$name" in
      vta) port=8100 ;;
      vtc) port=8200 ;;
      dids) port=8534 ;;
    esac
    sudo tee "/etc/nginx/sites-available/${name}.conf" >/dev/null <<EOF
server {
    listen 80;
    server_name ${name}.${DOMAIN};

    location / {
        proxy_pass http://127.0.0.1:${port};
        proxy_set_header Host \$host;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Host \$host;
    }
}
EOF
  done
}

obtain_certificates() {
  local -a domains=(-d "vtc.${DOMAIN}" -d "vta.${DOMAIN}" -d "dids.${DOMAIN}" -d "mediator.${DOMAIN}")
  local -a account
  if [ -n "$EMAIL" ]; then
    account=(--email "$EMAIL")
  else
    account=(--register-unsafely-without-email)
  fi

  if sudo certbot --nginx "${domains[@]}" "${account[@]}" --agree-tos --non-interactive; then
    echo -e "${GREEN}Certbot completed successfully.${NC}"
  else
    echo -e "${YELLOW}Certbot did not complete (e.g. DNS not ready).${NC}"
    echo -e "You can run manually later:"
    echo "  sudo certbot --nginx ${domains[*]} ${account[*]} --agree-tos"
  fi
}

check_url() {
  local url="$1"
  local code
  code=$(curl -sS -o /dev/null -w "%{http_code}" --connect-timeout 5 "$url" 2>/dev/null) || code="000"
  if [ "$code" = "502" ]; then
    echo -e "  ${GREEN}$url → 502 (backend not running yet) — URL set up successfully.${NC}"
  elif [ "$code" = "200" ]; then
    echo -e "  ${GREEN}$url → 200 OK — URL set up successfully.${NC}"
  else
    echo -e "  ${YELLOW}$url → HTTP $code${NC}"
  fi
}

main() {
  if [ "$#" -gt 2 ]; then
    usage
  fi
  DOMAIN="${1:-}"
  EMAIL="${2:-}"
  validate_args

  echo -e "${GREEN}=== VTI Stack Explore Setup ===${NC}"
  echo -e "${GREEN}Domain: $DOMAIN${NC}"
  if [ -n "$EMAIL" ]; then
    echo -e "${GREEN}Email: $EMAIL${NC}"
  else
    echo -e "${YELLOW}Email: (not provided — certbot will register without email)${NC}"
  fi
  echo ""

  # ---------------------------------------------------------------------------
  echo -e "${GREEN}>>> Step 1/8: Update system <<<${NC}"
  # ---------------------------------------------------------------------------
  apt_get update
  apt_get upgrade

  # ---------------------------------------------------------------------------
  echo -e "${GREEN}>>> Step 2/8: Install build and runtime dependencies <<<${NC}"
  # ---------------------------------------------------------------------------
  apt_get install git curl build-essential pkg-config libssl-dev clang cmake ca-certificates libdbus-1-dev ufw valkey-server

  # Valkey backs the mediator's queue + storage. Debian/Ubuntu packaging
  # binds 127.0.0.1 and enables the unit on install — confirm both.
  sudo systemctl is-active --quiet valkey-server || sudo systemctl enable --now valkey-server
  local listeners
  listeners=$(ss -tln 'sport = :6379' 2>/dev/null) || listeners=""
  if grep -q '127\.0\.0\.1' <<<"$listeners"; then
    echo -e "${GREEN}Valkey listening on 127.0.0.1:6379.${NC}"
  else
    echo -e "${YELLOW}Valkey not on 127.0.0.1:6379 — check /etc/valkey/valkey.conf bind setting.${NC}"
  fi

  # ---------------------------------------------------------------------------
  echo -e "${GREEN}>>> Step 3/8: Configure UFW firewall <<<${NC}"
  # ---------------------------------------------------------------------------
  sudo ufw default deny incoming
  sudo ufw default allow outgoing
  sudo ufw allow 22/tcp
  sudo ufw allow 80/tcp
  sudo ufw allow 443/tcp
  sudo ufw --force enable
  sudo ufw status

  # ---------------------------------------------------------------------------
  echo -e "${GREEN}>>> Step 4/8: Install Rust <<<${NC}"
  # ---------------------------------------------------------------------------
  install_rust

  # ---------------------------------------------------------------------------
  echo -e "${GREEN}>>> Step 5/8: Install Nginx and Certbot <<<${NC}"
  # ---------------------------------------------------------------------------
  apt_get install nginx
  sudo systemctl enable --now nginx
  if command -v certbot >/dev/null 2>&1; then
    echo -e "${GREEN}Certbot already installed.${NC}"
  else
    sudo snap install --classic certbot
    sudo ln -sf /snap/bin/certbot /usr/bin/certbot
  fi

  # ---------------------------------------------------------------------------
  echo -e "${GREEN}>>> Step 6/8: Create Nginx configs and enable sites <<<${NC}"
  # ---------------------------------------------------------------------------
  echo -e "${YELLOW}Creating Nginx configuration files...${NC}"
  write_nginx_configs

  echo -e "${YELLOW}Enabling sites...${NC}"
  local site
  for site in mediator vta vtc dids; do
    sudo ln -sf "/etc/nginx/sites-available/${site}.conf" /etc/nginx/sites-enabled/
  done

  echo -e "${YELLOW}Testing Nginx configuration...${NC}"
  if sudo nginx -t; then
    echo -e "${GREEN}Nginx config test passed.${NC}"
  else
    die "Nginx config test failed. Please check your setup."
  fi

  echo -e "${YELLOW}Reloading Nginx...${NC}"
  sudo systemctl reload nginx || sudo service nginx reload

  # ---------------------------------------------------------------------------
  echo -e "${GREEN}>>> Step 7/8: Obtain SSL certificates (Certbot) <<<${NC}"
  # ---------------------------------------------------------------------------
  obtain_certificates

  # ---------------------------------------------------------------------------
  echo -e "${GREEN}>>> Step 8/8: Verify URLs <<<${NC}"
  # ---------------------------------------------------------------------------
  echo ""
  check_url "https://mediator.${DOMAIN}"
  check_url "https://vta.${DOMAIN}"
  check_url "https://vtc.${DOMAIN}"
  check_url "https://dids.${DOMAIN}"

  echo ""
  echo -e "${GREEN}Setup complete.${NC}"
  echo -e "  Sites:"
  echo -e "    - https://mediator.${DOMAIN} → localhost:7037"
  echo -e "    - https://vta.${DOMAIN}      → localhost:8100"
  echo -e "    - https://vtc.${DOMAIN}      → localhost:8200"
  echo -e "    - https://dids.${DOMAIN}     → localhost:8534"
  echo ""
  echo -e "${YELLOW}NOTE: binaries from 'cargo install' go to ~/.cargo/bin, which new login shells now have on PATH.${NC}"
  echo -e "${YELLOW}To use them in your current shell, run:${NC}"
  echo -e "    export PATH=\"\$HOME/.cargo/bin:\$PATH\""
  echo -e "${YELLOW}Or start a new login shell (logout and back in).${NC}"
}

main "$@"
