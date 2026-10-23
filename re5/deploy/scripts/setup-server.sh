#!/bin/bash
# One-time setup for a fresh Ubuntu 24.04 server. Run as root.
set -euo pipefail

apt-get update
apt-get upgrade -y
apt-get install -y ca-certificates curl ufw unattended-upgrades

if ! command -v docker &>/dev/null; then
  curl -fsSL https://get.docker.com | sh
fi

ufw default deny incoming
ufw default allow outgoing
ufw allow OpenSSH
ufw allow 80/tcp
ufw allow 443/tcp
ufw --force enable

dpkg-reconfigure -f noninteractive unattended-upgrades

echo "Server ready. Next: copy re5/deploy to /opt/re5-crm and fill in .env (see re5/README.md)."
