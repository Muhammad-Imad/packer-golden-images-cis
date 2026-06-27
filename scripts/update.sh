#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# update.sh — patch the base OS to the latest packages before hardening.
# Detects the distribution family and uses the appropriate package manager.
# -----------------------------------------------------------------------------
set -euo pipefail

echo "[update] detecting distribution"
. /etc/os-release

# Avoid interactive prompts on Debian/Ubuntu.
export DEBIAN_FRONTEND=noninteractive

case "${ID}" in
  ubuntu|debian)
    echo "[update] apt-get update && full-upgrade"
    apt-get update -y
    apt-get -o Dpkg::Options::="--force-confnew" -y full-upgrade
    apt-get -y install jq curl ca-certificates gnupg auditd audispd-plugins \
      apparmor apparmor-utils libpam-pwquality unzip chrony
    apt-get -y autoremove --purge
    ;;
  rhel|rocky|almalinux|centos)
    echo "[update] dnf upgrade"
    dnf -y upgrade --refresh
    dnf -y install jq curl ca-certificates audit policycoreutils \
      libpwquality unzip chrony
    ;;
  amzn)
    echo "[update] dnf upgrade (Amazon Linux 2023)"
    dnf -y upgrade --refresh
    dnf -y install jq audit policycoreutils libpwquality chrony
    ;;
  *)
    echo "[update] WARNING: unrecognised distribution '${ID}', skipping package phase"
    ;;
esac

echo "[update] complete"
