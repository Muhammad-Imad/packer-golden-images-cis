#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# validate.sh — lightweight in-image self-check that fails the build if a core
# hardening control is missing. This is a smoke test, not a full CIS audit;
# pair it with OpenSCAP/inspec in CI for a complete attestation.
# -----------------------------------------------------------------------------
set -uo pipefail

FAIL=0
pass() { echo "  [PASS] $1"; }
fail() { echo "  [FAIL] $1"; FAIL=1; }

echo "[validate] running golden-image self-checks"

# 1. sshd hardening drop-in present and root login disabled.
if grep -q '^PermitRootLogin no' /etc/ssh/sshd_config.d/60-cis-hardening.conf 2>/dev/null; then
  pass "sshd PermitRootLogin disabled"
else
  fail "sshd PermitRootLogin not disabled"
fi

if grep -q '^PasswordAuthentication no' /etc/ssh/sshd_config.d/60-cis-hardening.conf 2>/dev/null; then
  pass "sshd PasswordAuthentication disabled"
else
  fail "sshd PasswordAuthentication not disabled"
fi

# 2. sysctl drop-in applied.
if [ -f /etc/sysctl.d/60-cis-hardening.conf ]; then
  pass "sysctl hardening drop-in present"
else
  fail "sysctl hardening drop-in missing"
fi

# 3. auditd enabled and rules present.
if systemctl is-enabled auditd >/dev/null 2>&1; then
  pass "auditd enabled"
else
  fail "auditd not enabled"
fi
if [ -f /etc/audit/rules.d/cis.rules ]; then
  pass "audit rules present"
else
  fail "audit rules missing"
fi

# 4. Disabled kernel modules drop-in.
if [ -f /etc/modprobe.d/cis-disabled.conf ]; then
  pass "modprobe disable list present"
else
  fail "modprobe disable list missing"
fi

# 5. SSM agent enabled (best-effort — agent name varies by distro).
if systemctl is-enabled amazon-ssm-agent >/dev/null 2>&1 || \
   systemctl is-enabled snap.amazon-ssm-agent.amazon-ssm-agent.service >/dev/null 2>&1; then
  pass "SSM agent enabled"
else
  fail "SSM agent not enabled"
fi

if [ "${FAIL}" -ne 0 ]; then
  echo "[validate] one or more checks FAILED — failing the build"
  exit 1
fi

echo "[validate] all self-checks passed"
