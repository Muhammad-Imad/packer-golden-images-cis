#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# cis-hardening.sh — apply a representative subset of CIS Benchmark controls to
# Ubuntu 24.04, RHEL 9 and Amazon Linux 2023.
#
# This is an ORIGINAL, distilled implementation intended for demonstration. It
# is NOT a drop-in replacement for a fully audited CIS profile — run a scanner
# (OpenSCAP / inspec) against the resulting image and tune to your policy.
#
# Honours CIS_PROFILE=level1_server (default) or level2_server, where level2
# enables a few additional, more restrictive controls.
# -----------------------------------------------------------------------------
set -euo pipefail

CIS_PROFILE="${CIS_PROFILE:-level1_server}"
echo "[cis] applying profile: ${CIS_PROFILE}"

. /etc/os-release
FAMILY="rhel"
case "${ID}" in
  ubuntu|debian) FAMILY="debian" ;;
  rhel|rocky|almalinux|centos|amzn) FAMILY="rhel" ;;
esac
echo "[cis] detected family: ${FAMILY} (${PRETTY_NAME})"

# Helper: write a sysctl drop-in line only if absent.
backup_once() { [ -f "$1" ] && [ ! -f "$1.cis.bak" ] && cp -a "$1" "$1.cis.bak" || true; }

# -----------------------------------------------------------------------------
# 1. Filesystem — disable rarely needed kernel modules (CIS 1.1.x)
# -----------------------------------------------------------------------------
echo "[cis] 1. disabling unused filesystem/protocol kernel modules"
cat > /etc/modprobe.d/cis-disabled.conf <<'EOF'
# CIS: disable uncommon filesystems and network protocols
install cramfs /bin/false
install freevxfs /bin/false
install jffs2 /bin/false
install hfs /bin/false
install hfsplus /bin/false
install squashfs /bin/false
install udf /bin/false
install usb-storage /bin/false
install dccp /bin/false
install sctp /bin/false
install rds /bin/false
install tipc /bin/false
EOF

# -----------------------------------------------------------------------------
# 2. Filesystem mount hardening — tmpfs and shared memory (CIS 1.1.2.x)
# -----------------------------------------------------------------------------
echo "[cis] 2. hardening /tmp and /dev/shm mount options"
if ! grep -q '/dev/shm' /etc/fstab; then
  echo 'tmpfs /dev/shm tmpfs defaults,noexec,nosuid,nodev 0 0' >> /etc/fstab
fi
if ! grep -qE '^\s*tmpfs\s+/tmp' /etc/fstab; then
  echo 'tmpfs /tmp tmpfs defaults,rw,noexec,nosuid,nodev 0 0' >> /etc/fstab
fi

# -----------------------------------------------------------------------------
# 3. Kernel / network sysctl hardening (CIS 3.x)
# -----------------------------------------------------------------------------
echo "[cis] 3. applying sysctl network and kernel hardening"
cat > /etc/sysctl.d/60-cis-hardening.conf <<'EOF'
# --- Network hardening (CIS 3.x) ---
net.ipv4.ip_forward = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv4.conf.all.secure_redirects = 0
net.ipv4.conf.default.secure_redirects = 0
net.ipv4.conf.all.log_martians = 1
net.ipv4.conf.default.log_martians = 1
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.icmp_ignore_bogus_error_responses = 1
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1
net.ipv4.tcp_syncookies = 1
net.ipv6.conf.all.accept_ra = 0
net.ipv6.conf.default.accept_ra = 0
net.ipv6.conf.all.accept_redirects = 0
net.ipv6.conf.default.accept_redirects = 0
net.ipv6.conf.all.accept_source_route = 0
net.ipv6.conf.default.accept_source_route = 0
# --- Kernel hardening ---
kernel.randomize_va_space = 2
kernel.kptr_restrict = 2
kernel.dmesg_restrict = 1
kernel.yama.ptrace_scope = 1
fs.suid_dumpable = 0
fs.protected_hardlinks = 1
fs.protected_symlinks = 1
EOF
sysctl --system >/dev/null 2>&1 || true

# -----------------------------------------------------------------------------
# 4. SSH server hardening (CIS 5.x)
# -----------------------------------------------------------------------------
echo "[cis] 4. hardening sshd configuration"
install -d -m 0755 /etc/ssh/sshd_config.d
cat > /etc/ssh/sshd_config.d/60-cis-hardening.conf <<'EOF'
Protocol 2
LogLevel VERBOSE
PermitRootLogin no
PermitEmptyPasswords no
PasswordAuthentication no
ChallengeResponseAuthentication no
KbdInteractiveAuthentication no
PubkeyAuthentication yes
PermitUserEnvironment no
X11Forwarding no
AllowTcpForwarding no
IgnoreRhosts yes
HostbasedAuthentication no
MaxAuthTries 4
MaxSessions 4
LoginGraceTime 60
ClientAliveInterval 300
ClientAliveCountMax 2
Banner /etc/issue.net
Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes128-gcm@openssh.com,aes256-ctr,aes128-ctr
MACs hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com
KexAlgorithms curve25519-sha256,curve25519-sha256@libssh.org,diffie-hellman-group16-sha512
EOF
chmod 0600 /etc/ssh/sshd_config.d/60-cis-hardening.conf

# Login warning banner (CIS 1.7.x)
cat > /etc/issue.net <<'EOF'
Authorized uses only. All activity may be monitored and reported.
EOF
cp /etc/issue.net /etc/issue
cp /etc/issue.net /etc/motd

# -----------------------------------------------------------------------------
# 5. Password quality and account policy (CIS 5.4.x)
# -----------------------------------------------------------------------------
echo "[cis] 5. configuring password quality and login.defs"
if [ -f /etc/security/pwquality.conf ]; then
  backup_once /etc/security/pwquality.conf
  cat > /etc/security/pwquality.conf <<'EOF'
minlen = 14
dcredit = -1
ucredit = -1
ocredit = -1
lcredit = -1
minclass = 4
maxrepeat = 3
dictcheck = 1
enforcing = 1
EOF
fi

if [ -f /etc/login.defs ]; then
  backup_once /etc/login.defs
  sed -ri 's/^\s*PASS_MAX_DAYS.*/PASS_MAX_DAYS   365/' /etc/login.defs
  sed -ri 's/^\s*PASS_MIN_DAYS.*/PASS_MIN_DAYS   1/'   /etc/login.defs
  sed -ri 's/^\s*PASS_WARN_AGE.*/PASS_WARN_AGE   7/'   /etc/login.defs
  if grep -q '^UMASK' /etc/login.defs; then
    sed -ri 's/^\s*UMASK.*/UMASK           027/' /etc/login.defs
  else
    echo 'UMASK           027' >> /etc/login.defs
  fi
fi

# Default umask for interactive shells.
echo 'umask 027' > /etc/profile.d/cis-umask.sh
chmod 0644 /etc/profile.d/cis-umask.sh

# -----------------------------------------------------------------------------
# 6. auditd — service + rules (CIS 4.1.x)
# -----------------------------------------------------------------------------
echo "[cis] 6. configuring auditd rules"
install -d -m 0750 /etc/audit/rules.d
cat > /etc/audit/rules.d/cis.rules <<'EOF'
## Record changes to date/time
-a always,exit -F arch=b64 -S adjtimex,settimeofday -F key=time-change
-w /etc/localtime -p wa -k time-change
## Identity and account changes
-w /etc/group -p wa -k identity
-w /etc/passwd -p wa -k identity
-w /etc/gshadow -p wa -k identity
-w /etc/shadow -p wa -k identity
-w /etc/security/opasswd -p wa -k identity
## Network environment
-w /etc/hosts -p wa -k system-locale
-w /etc/sysconfig/network -p wa -k system-locale
## Login/logout events
-w /var/log/lastlog -p wa -k logins
-w /var/run/faillock -p wa -k logins
## Session initiation
-w /var/run/utmp -p wa -k session
-w /var/log/wtmp -p wa -k session
-w /var/log/btmp -p wa -k session
## Privileged commands and access
-a always,exit -F arch=b64 -S execve -C uid!=euid -F euid=0 -k setuid-exec
-w /etc/sudoers -p wa -k scope
-w /etc/sudoers.d/ -p wa -k scope
-w /var/log/sudo.log -p wa -k actions
## Loading/unloading kernel modules
-a always,exit -F arch=b64 -S init_module,delete_module -k modules
## Discretionary access control changes
-a always,exit -F arch=b64 -S chmod,fchmod,fchmodat -F auid>=1000 -F auid!=4294967295 -k perm_mod
## Make the configuration immutable (must be the final rule)
-e 2
EOF

if command -v augenrules >/dev/null 2>&1; then
  augenrules --load >/dev/null 2>&1 || true
fi
systemctl enable auditd >/dev/null 2>&1 || true
# Capture events during early boot.
if [ -f /etc/default/grub ] && ! grep -q 'audit=1' /etc/default/grub; then
  sed -ri 's/^(GRUB_CMDLINE_LINUX=")/\1audit=1 audit_backlog_limit=8192 /' /etc/default/grub || true
fi

# -----------------------------------------------------------------------------
# 7. Disable unneeded / legacy services (CIS 2.x)
# -----------------------------------------------------------------------------
echo "[cis] 7. masking legacy / unused services"
for svc in avahi-daemon cups isc-dhcp-server slapd nfs-server rpcbind \
           rsync bind9 vsftpd telnet.socket squid snmpd; do
  systemctl disable --now "${svc}" >/dev/null 2>&1 || true
  systemctl mask "${svc}" >/dev/null 2>&1 || true
done

# Ensure time synchronisation is enabled (CIS 2.1.x).
systemctl enable --now chronyd >/dev/null 2>&1 || \
  systemctl enable --now chrony >/dev/null 2>&1 || true

# -----------------------------------------------------------------------------
# 8. Host firewall (CIS 3.5.x) — default-deny inbound, allow SSH + loopback
# -----------------------------------------------------------------------------
echo "[cis] 8. configuring host firewall"
if [ "${FAMILY}" = "debian" ]; then
  if command -v ufw >/dev/null 2>&1; then
    ufw --force reset >/dev/null 2>&1 || true
    ufw default deny incoming
    ufw default allow outgoing
    ufw allow 22/tcp
    ufw --force enable
  fi
else
  if command -v firewall-cmd >/dev/null 2>&1; then
    systemctl enable --now firewalld >/dev/null 2>&1 || true
    firewall-cmd --permanent --set-default-zone=drop >/dev/null 2>&1 || true
    firewall-cmd --permanent --zone=drop --add-service=ssh >/dev/null 2>&1 || true
    firewall-cmd --reload >/dev/null 2>&1 || true
  fi
fi

# -----------------------------------------------------------------------------
# 9. Mandatory Access Control (CIS 1.6.x)
# -----------------------------------------------------------------------------
echo "[cis] 9. ensuring MAC (AppArmor / SELinux) is enforcing"
if [ "${FAMILY}" = "debian" ]; then
  systemctl enable --now apparmor >/dev/null 2>&1 || true
  aa-enforce /etc/apparmor.d/* >/dev/null 2>&1 || true
else
  if [ -f /etc/selinux/config ]; then
    sed -ri 's/^SELINUX=.*/SELINUX=enforcing/' /etc/selinux/config
    sed -ri 's/^SELINUXTYPE=.*/SELINUXTYPE=targeted/' /etc/selinux/config
  fi
fi

# -----------------------------------------------------------------------------
# 10. Restrict cron / at to root and harden permissions (CIS 5.1.x)
# -----------------------------------------------------------------------------
echo "[cis] 10. restricting cron and at"
for f in /etc/cron.allow /etc/at.allow; do
  echo root > "${f}"; chmod 0600 "${f}"; chown root:root "${f}"
done
rm -f /etc/cron.deny /etc/at.deny
for d in /etc/crontab /etc/cron.hourly /etc/cron.daily /etc/cron.weekly \
         /etc/cron.monthly /etc/cron.d; do
  [ -e "${d}" ] && chmod -R go-rwx "${d}" || true
done

# Lock down sensitive file permissions (CIS 6.1.x).
chmod 0644 /etc/passwd /etc/group
chmod 0000 /etc/shadow /etc/gshadow 2>/dev/null || true
chmod 0600 /boot/grub/grub.cfg 2>/dev/null || \
  chmod 0600 /boot/grub2/grub.cfg 2>/dev/null || true

# -----------------------------------------------------------------------------
# 11. Account lockout on failed auth via faillock / tally (CIS 5.3.x)
# -----------------------------------------------------------------------------
echo "[cis] 11. configuring account lockout policy"
if [ -f /etc/security/faillock.conf ]; then
  backup_once /etc/security/faillock.conf
  cat > /etc/security/faillock.conf <<'EOF'
deny = 5
unlock_time = 900
fail_interval = 900
EOF
fi

# -----------------------------------------------------------------------------
# 12. Level 2 — additional, more restrictive controls
# -----------------------------------------------------------------------------
if [ "${CIS_PROFILE}" = "level2_server" ]; then
  echo "[cis] 12. applying level2 additional controls"
  # Disable IPv6 entirely unless required.
  echo 'net.ipv6.conf.all.disable_ipv6 = 1'     >> /etc/sysctl.d/60-cis-hardening.conf
  echo 'net.ipv6.conf.default.disable_ipv6 = 1' >> /etc/sysctl.d/60-cis-hardening.conf
  # Restrict core dumps hard.
  echo '* hard core 0' > /etc/security/limits.d/cis-coredump.conf
  # Disable wireless interfaces (servers should have none).
  if command -v nmcli >/dev/null 2>&1; then
    nmcli radio all off >/dev/null 2>&1 || true
  fi
  sysctl --system >/dev/null 2>&1 || true
fi

echo "[cis] hardening complete for profile ${CIS_PROFILE}"
