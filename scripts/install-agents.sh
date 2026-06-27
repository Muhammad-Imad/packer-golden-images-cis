#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# install-agents.sh — install and enable the AWS operational agents that every
# golden image should ship with: the SSM Agent and the CloudWatch Agent.
# The agents are enabled but NOT started with instance-specific config; that is
# delivered at launch via SSM Parameter Store / instance profile.
# -----------------------------------------------------------------------------
set -euo pipefail

AWS_REGION="${AWS_REGION:-us-east-1}"
. /etc/os-release
ARCH="$(uname -m)"
echo "[agents] region=${AWS_REGION} arch=${ARCH} os=${ID}"

# Map uname arch to the suffix used in AWS download URLs.
case "${ARCH}" in
  x86_64) CW_ARCH="amd64"; PKG_ARCH="amd64" ;;
  aarch64) CW_ARCH="arm64"; PKG_ARCH="arm64" ;;
  *) CW_ARCH="amd64"; PKG_ARCH="amd64" ;;
esac

install_deb() {
  local url="$1" out="$2"
  curl -fsSL "${url}" -o "${out}"
  dpkg -i "${out}" || (apt-get update -y && apt-get -f install -y)
  rm -f "${out}"
}

install_rpm() {
  local url="$1"
  dnf -y install "${url}" || rpm -Uvh "${url}"
}

# --- SSM Agent ---------------------------------------------------------------
echo "[agents] installing SSM agent"
case "${ID}" in
  ubuntu|debian)
    if ! snap list amazon-ssm-agent >/dev/null 2>&1; then
      install_deb \
        "https://s3.${AWS_REGION}.amazonaws.com/amazon-ssm-${AWS_REGION}/latest/debian_${PKG_ARCH}/amazon-ssm-agent.deb" \
        "/tmp/ssm.deb"
    fi
    systemctl enable amazon-ssm-agent >/dev/null 2>&1 || \
      systemctl enable snap.amazon-ssm-agent.amazon-ssm-agent.service >/dev/null 2>&1 || true
    ;;
  amzn)
    echo "[agents] SSM agent ships with Amazon Linux 2023; enabling"
    systemctl enable amazon-ssm-agent >/dev/null 2>&1 || true
    ;;
  rhel|rocky|almalinux|centos)
    install_rpm \
      "https://s3.${AWS_REGION}.amazonaws.com/amazon-ssm-${AWS_REGION}/latest/linux_${PKG_ARCH}/amazon-ssm-agent.rpm"
    systemctl enable amazon-ssm-agent >/dev/null 2>&1 || true
    ;;
esac

# --- CloudWatch Agent --------------------------------------------------------
echo "[agents] installing CloudWatch agent"
case "${ID}" in
  ubuntu|debian)
    install_deb \
      "https://s3.${AWS_REGION}.amazonaws.com/amazoncloudwatch-agent-${AWS_REGION}/ubuntu/${CW_ARCH}/latest/amazon-cloudwatch-agent.deb" \
      "/tmp/cwagent.deb"
    ;;
  amzn|rhel|rocky|almalinux|centos)
    install_rpm \
      "https://s3.${AWS_REGION}.amazonaws.com/amazoncloudwatch-agent-${AWS_REGION}/amazon_linux/${CW_ARCH}/latest/amazon-cloudwatch-agent.rpm"
    ;;
esac

# Ship a baseline collectd-style config; instances may override via SSM at boot.
install -d -m 0755 /opt/aws/amazon-cloudwatch-agent/etc
cat > /opt/aws/amazon-cloudwatch-agent/etc/baseline-config.json <<'EOF'
{
  "agent": { "metrics_collection_interval": 60, "run_as_user": "root" },
  "metrics": {
    "namespace": "GoldenImage/Host",
    "append_dimensions": { "InstanceId": "${aws:InstanceId}" },
    "metrics_collected": {
      "mem":  { "measurement": ["mem_used_percent"] },
      "disk": { "measurement": ["used_percent"], "resources": ["/"] },
      "swap": { "measurement": ["swap_used_percent"] }
    }
  },
  "logs": {
    "logs_collected": {
      "files": {
        "collect_list": [
          { "file_path": "/var/log/secure",    "log_group_name": "/golden/secure" },
          { "file_path": "/var/log/audit/audit.log", "log_group_name": "/golden/audit" }
        ]
      }
    }
  }
}
EOF

# Enable (do not start) so the agent picks up its config at first boot.
systemctl enable amazon-cloudwatch-agent >/dev/null 2>&1 || true

echo "[agents] installation complete"
