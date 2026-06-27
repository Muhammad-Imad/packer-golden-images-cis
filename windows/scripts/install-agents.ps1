# -----------------------------------------------------------------------------
# install-agents.ps1 — install the AWS operational agents into the Windows
# golden image: the SSM Agent (usually preinstalled, refreshed here) and the
# CloudWatch Agent. Agents are configured to start automatically but pick up
# instance-specific config from SSM Parameter Store at launch.
# -----------------------------------------------------------------------------
$ErrorActionPreference = "Stop"
$region = if ($env:AWS_REGION) { $env:AWS_REGION } else { "us-east-1" }
Write-Host "[agents] region=$region"

$dl = "$env:TEMP\agents"
New-Item -ItemType Directory -Path $dl -Force | Out-Null

# --- SSM Agent ---------------------------------------------------------------
Write-Host "[agents] installing/refreshing SSM agent"
$ssmInstaller = "$dl\SSMAgent_latest.exe"
Invoke-WebRequest `
  -Uri "https://s3.$region.amazonaws.com/amazon-ssm-$region/latest/windows_amd64/AmazonSSMAgentSetup.exe" `
  -OutFile $ssmInstaller -UseBasicParsing
Start-Process -FilePath $ssmInstaller -ArgumentList "/S" -Wait
Set-Service -Name AmazonSSMAgent -StartupType Automatic -ErrorAction SilentlyContinue

# --- CloudWatch Agent --------------------------------------------------------
Write-Host "[agents] installing CloudWatch agent"
$cwInstaller = "$dl\amazon-cloudwatch-agent.msi"
Invoke-WebRequest `
  -Uri "https://s3.$region.amazonaws.com/amazoncloudwatch-agent-$region/windows/amd64/latest/amazon-cloudwatch-agent.msi" `
  -OutFile $cwInstaller -UseBasicParsing
Start-Process msiexec.exe -ArgumentList "/i `"$cwInstaller`" /qn" -Wait

# Ship a baseline config; instances override via SSM at boot.
$cwDir = "$env:ProgramFiles\Amazon\AmazonCloudWatchAgent"
$baseline = @'
{
  "agent": { "metrics_collection_interval": 60 },
  "metrics": {
    "namespace": "GoldenImage/Host",
    "append_dimensions": { "InstanceId": "${aws:InstanceId}" },
    "metrics_collected": {
      "Memory":        { "measurement": ["% Committed Bytes In Use"] },
      "LogicalDisk":   { "measurement": ["% Free Space"], "resources": ["*"] }
    }
  },
  "logs": {
    "logs_collected": {
      "windows_events": {
        "collect_list": [
          { "event_name": "Security", "event_levels": ["WARNING","ERROR","CRITICAL"],
            "log_group_name": "/golden/windows/security" },
          { "event_name": "System",   "event_levels": ["ERROR","CRITICAL"],
            "log_group_name": "/golden/windows/system" }
        ]
      }
    }
  }
}
'@
if (Test-Path $cwDir) {
  Set-Content -Path "$cwDir\baseline-config.json" -Value $baseline -Encoding UTF8
}

Remove-Item $dl -Recurse -Force -ErrorAction SilentlyContinue
Write-Host "[agents] installation complete"
