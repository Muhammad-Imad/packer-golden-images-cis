#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# cleanup.sh — final pass before the snapshot is taken. Removes anything that
# would either leak across instances (SSH host keys, machine-id) or bloat the
# image (package caches, logs, shell history).
# -----------------------------------------------------------------------------
set -uo pipefail
. /etc/os-release

echo "[cleanup] removing package manager caches"
case "${ID}" in
  ubuntu|debian)
    apt-get -y autoremove --purge >/dev/null 2>&1 || true
    apt-get -y clean
    rm -rf /var/lib/apt/lists/*
    ;;
  amzn|rhel|rocky|almalinux|centos)
    dnf clean all >/dev/null 2>&1 || true
    rm -rf /var/cache/dnf/* /var/cache/yum/* 2>/dev/null || true
    ;;
esac

echo "[cleanup] truncating logs"
find /var/log -type f -exec truncate -s 0 {} \; 2>/dev/null || true
rm -rf /var/log/journal/* 2>/dev/null || true
rm -f /var/log/wtmp /var/log/btmp /var/log/lastlog 2>/dev/null || true

echo "[cleanup] removing SSH host keys (regenerated on first boot)"
rm -f /etc/ssh/ssh_host_* 2>/dev/null || true

echo "[cleanup] resetting machine-id (regenerated on first boot)"
truncate -s 0 /etc/machine-id 2>/dev/null || true
rm -f /var/lib/dbus/machine-id 2>/dev/null || true
ln -sf /etc/machine-id /var/lib/dbus/machine-id 2>/dev/null || true

echo "[cleanup] removing cloud-init state so the image re-initialises cleanly"
command -v cloud-init >/dev/null 2>&1 && cloud-init clean --logs --seed >/dev/null 2>&1 || true

echo "[cleanup] removing shell history and temp data"
rm -rf /tmp/* /var/tmp/* 2>/dev/null || true
unset HISTFILE
for home in /root /home/*; do
  rm -f "${home}/.bash_history" "${home}/.zsh_history" 2>/dev/null || true
  rm -rf "${home}/.cache" 2>/dev/null || true
done

echo "[cleanup] removing build-time authorized_keys for the default user"
# Packer's temporary key is removed automatically, but scrub any stragglers.
find /home -name authorized_keys -path '*/.ssh/*' -exec truncate -s 0 {} \; 2>/dev/null || true

echo "[cleanup] zeroing free space to improve snapshot compression (best-effort)"
dd if=/dev/zero of=/EMPTY bs=1M 2>/dev/null || true
rm -f /EMPTY
sync

echo "[cleanup] complete"
