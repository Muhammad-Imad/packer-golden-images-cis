#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# ubuntu/scripts/extra-hardening.sh — Ubuntu-specific controls layered on top of
# the shared scripts/cis-hardening.sh. Wire this in by adding it to the Ubuntu
# source's provisioner list when you need Ubuntu-only tuning.
# -----------------------------------------------------------------------------
set -euo pipefail
echo "[ubuntu] applying Ubuntu-specific hardening"

# Enable unattended security upgrades (CIS 1.9 — patch management).
export DEBIAN_FRONTEND=noninteractive
apt-get -y install unattended-upgrades apt-listchanges
cat > /etc/apt/apt.conf.d/51cis-unattended <<'EOF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
Unattended-Upgrade::Remove-Unused-Dependencies "true";
EOF

# Ensure AppArmor profiles are loaded in enforce mode.
systemctl enable --now apparmor
aa-enforce /etc/apparmor.d/* 2>/dev/null || true

# Disable the GUI/cloud snaps that have no place on a server image.
snap list 2>/dev/null | awk 'NR>1 {print $1}' | \
  grep -E '^(lxd|gnome|firefox)$' | xargs -r -n1 snap remove 2>/dev/null || true

echo "[ubuntu] done"
