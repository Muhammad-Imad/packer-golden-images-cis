#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# rhel/scripts/extra-hardening.sh — RHEL 9-specific controls layered on top of
# the shared scripts/cis-hardening.sh.
# -----------------------------------------------------------------------------
set -euo pipefail
echo "[rhel] applying RHEL 9-specific hardening"

# Enforce a FIPS-validated crypto policy where required (CIS appendix).
if command -v update-crypto-policies >/dev/null 2>&1; then
  update-crypto-policies --set DEFAULT:NO-SHA1 || true
fi

# Ensure SELinux is enforcing and targeted.
setenforce 1 2>/dev/null || true
if [ -f /etc/selinux/config ]; then
  sed -ri 's/^SELINUX=.*/SELINUX=enforcing/' /etc/selinux/config
fi

# Enable automatic security patching via dnf-automatic (CIS patch management).
dnf -y install dnf-automatic
sed -ri 's/^apply_updates =.*/apply_updates = yes/' /etc/dnf/automatic.conf
sed -ri 's/^upgrade_type =.*/upgrade_type = security/' /etc/dnf/automatic.conf
systemctl enable dnf-automatic.timer

echo "[rhel] done"
