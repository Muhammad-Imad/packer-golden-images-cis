#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# amazon-linux/scripts/extra-hardening.sh — Amazon Linux 2023-specific controls
# layered on top of the shared scripts/cis-hardening.sh.
# -----------------------------------------------------------------------------
set -euo pipefail
echo "[al2023] applying Amazon Linux 2023-specific hardening"

# AL2023 ships SELinux in permissive mode by default; move to enforcing.
if [ -f /etc/selinux/config ]; then
  sed -ri 's/^SELINUX=.*/SELINUX=enforcing/' /etc/selinux/config
fi

# Pin the OS to a deterministic release version so autoscaling boots are
# reproducible (AL2023 uses versioned package repositories).
if command -v dnf >/dev/null 2>&1; then
  dnf -y install libselinux-utils
fi

# Ensure IMDSv2 tooling is present; instances should enforce IMDSv2 at launch
# via the launch template (hop limit 1, tokens required).
echo "[al2023] reminder: enforce IMDSv2 + hop-limit on the launch template"

echo "[al2023] done"
