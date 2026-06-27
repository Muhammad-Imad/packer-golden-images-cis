<powershell>
# -----------------------------------------------------------------------------
# bootstrap-winrm.ps1 — EC2 user-data executed on first boot to enable WinRM
# over HTTPS so Packer can connect. A self-signed certificate is generated for
# the build only; it is removed during sysprep and never ships in the AMI.
# -----------------------------------------------------------------------------
$ErrorActionPreference = "Stop"

Write-Host "[bootstrap] configuring WinRM for Packer build"

# Generate a short-lived self-signed cert for the HTTPS listener.
$cert = New-SelfSignedCertificate `
  -DnsName  "packer-build" `
  -CertStoreLocation "Cert:\LocalMachine\My"

# Ensure the WinRM service is running and set to start automatically.
Set-Service  -Name WinRM -StartupType Automatic
Start-Service -Name WinRM

# Remove any existing HTTPS listener, then create a fresh one bound to the cert.
Get-ChildItem WSMan:\localhost\Listener | Where-Object {
  $_.Keys -contains "Transport=HTTPS"
} | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue

New-Item -Path WSMan:\localhost\Listener `
  -Transport HTTPS -Address * `
  -CertificateThumbPrint $cert.Thumbprint -Force | Out-Null

# Allow Basic auth + unencrypted negotiation for the build session only.
Set-Item -Path WSMan:\localhost\Service\Auth\Basic            -Value $true
Set-Item -Path WSMan:\localhost\Service\AllowUnencrypted      -Value $false
Set-Item -Path WSMan:\localhost\MaxTimeoutms                  -Value 1800000

# Open the firewall for the HTTPS listener.
New-NetFirewallRule -DisplayName "WinRM HTTPS (Packer build)" `
  -Direction Inbound -LocalPort 5986 -Protocol TCP -Action Allow `
  -ErrorAction SilentlyContinue | Out-Null

Write-Host "[bootstrap] WinRM HTTPS listener ready"
</powershell>
