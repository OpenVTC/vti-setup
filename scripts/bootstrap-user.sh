#!/bin/bash

# bootstrap-user.sh — stage 1 of VTI server setup.
#
# Run once, as root, over the default SSH session of a fresh Ubuntu host.
#
# Creates a non-root operator user ('vti'), copies its SSH key from root, and
# hardens sshd so root login and password authentication are disabled. After
# this script finishes, you must reconnect as 'vti' before running stage 2
# (scripts/ubuntu-server-setup.sh).
#
# Usage:
#   curl -sSL https://raw.githubusercontent.com/OpenVTC/vti-setup/main/scripts/bootstrap-user.sh | bash

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

USERNAME="vti"
SSHD_DROPIN="/etc/ssh/sshd_config.d/01-vti-hardening.conf"
SUDOERS_FILE="/etc/sudoers.d/90-vti-nopasswd"

if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}Error: bootstrap-user.sh must be run as root.${NC}"
  exit 1
fi

if [ ! -f /root/.ssh/authorized_keys ]; then
  echo -e "${RED}Error: /root/.ssh/authorized_keys is missing.${NC}"
  echo -e "${RED}Refusing to harden sshd — you would be locked out.${NC}"
  exit 1
fi

echo -e "${GREEN}=== Stage 1: bootstrap operator user '${USERNAME}' ===${NC}"
echo ""

# -----------------------------------------------------------------------------
echo -e "${GREEN}>>> Step 1/5: Create user '${USERNAME}' <<<${NC}"
# -----------------------------------------------------------------------------
if id -u "$USERNAME" >/dev/null 2>&1; then
  echo -e "${YELLOW}User '${USERNAME}' already exists, skipping creation.${NC}"
else
  adduser --disabled-password --gecos "" "$USERNAME"
fi
usermod -aG sudo "$USERNAME"

# -----------------------------------------------------------------------------
echo -e "${GREEN}>>> Step 2/5: Grant passwordless sudo to '${USERNAME}' <<<${NC}"
# -----------------------------------------------------------------------------
# vti was created with --disabled-password, so sudo's normal password prompt
# can't authenticate. SSH password auth is also disabled, so the only way onto
# the box is the vti SSH key — NOPASSWD sudo adds no real attack surface.
TMP_SUDOERS=$(mktemp)
echo "${USERNAME} ALL=(ALL) NOPASSWD:ALL" > "$TMP_SUDOERS"
if ! visudo -c -f "$TMP_SUDOERS" >/dev/null; then
  echo -e "${RED}sudoers fragment failed validation. Aborting.${NC}"
  rm -f "$TMP_SUDOERS"
  exit 1
fi
install -m 440 -o root -g root "$TMP_SUDOERS" "$SUDOERS_FILE"
rm -f "$TMP_SUDOERS"

# -----------------------------------------------------------------------------
echo -e "${GREEN}>>> Step 3/5: Install SSH keys for '${USERNAME}' <<<${NC}"
# -----------------------------------------------------------------------------
HOME_DIR="/home/${USERNAME}"
install -d -m 700 -o "$USERNAME" -g "$USERNAME" "${HOME_DIR}/.ssh"
install -m 600 -o "$USERNAME" -g "$USERNAME" /root/.ssh/authorized_keys "${HOME_DIR}/.ssh/authorized_keys"

# -----------------------------------------------------------------------------
echo -e "${GREEN}>>> Step 4/5: Harden sshd (no root login, no password auth) <<<${NC}"
# -----------------------------------------------------------------------------
# Write a drop-in that beats any Ubuntu cloud-init default (drop-ins are
# processed first, first-match-wins for most options).
cat > "$SSHD_DROPIN" <<'EOF'
# VTI hardening — created by bootstrap-user.sh
PermitRootLogin no
PasswordAuthentication no
EOF
chmod 644 "$SSHD_DROPIN"

if ! sshd -t; then
  echo -e "${RED}sshd config test failed. Refusing to reload — fix ${SSHD_DROPIN} and retry.${NC}"
  exit 1
fi

# -----------------------------------------------------------------------------
echo -e "${GREEN}>>> Step 5/5: Reload sshd <<<${NC}"
# -----------------------------------------------------------------------------
systemctl reload ssh

echo ""
echo -e "${GREEN}Stage 1 complete.${NC}"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "  1. Disconnect from this SSH session."
echo "  2. Reconnect as '${USERNAME}@<host>' using your existing SSH key."
echo "  3. Run stage 2:"
echo "       curl -sSL https://raw.githubusercontent.com/OpenVTC/vti-setup/main/scripts/ubuntu-server-setup.sh | bash -s -- <domain> [email]"
echo "     Add --dev if this box will build the binaries from source."
