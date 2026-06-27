# -----------------------------------------------------------------------------
# sysprep.ps1 — generalise the Windows image so every launched instance gets a
# unique SID, computer name and freshly initialised state. Uses EC2Launch v2
# (Windows Server 2022/2025), which wraps Sysprep and re-arms the OOBE flow.
# This MUST be the final provisioner — the instance shuts down afterwards.
# -----------------------------------------------------------------------------
$ErrorActionPreference = "Stop"
Write-Host "[sysprep] preparing image for generalisation"

# Scrub build-time WinRM HTTPS listener + firewall rule so they do not ship.
Write-Host "[sysprep] removing temporary WinRM build configuration"
Get-ChildItem WSMan:\localhost\Listener -ErrorAction SilentlyContinue |
  Where-Object { $_.Keys -contains "Transport=HTTPS" } |
  Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
Remove-NetFirewallRule -DisplayName "WinRM HTTPS (Packer build)" -ErrorAction SilentlyContinue
Get-ChildItem Cert:\LocalMachine\My |
  Where-Object { $_.Subject -eq "CN=packer-build" } |
  Remove-Item -Force -ErrorAction SilentlyContinue

# Clear event logs and temp data so they do not leak into the AMI.
Write-Host "[sysprep] clearing event logs and temp data"
wevtutil el | ForEach-Object { wevtutil cl "$_" 2>$null }
Remove-Item "$env:TEMP\*"          -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item "$env:windir\Temp\*"   -Recurse -Force -ErrorAction SilentlyContinue

# Invoke EC2Launch v2 to generalise; the agent shuts the instance down when done.
$ec2launch = "$env:ProgramFiles\Amazon\EC2Launch\EC2Launch.exe"
if (Test-Path $ec2launch) {
  Write-Host "[sysprep] running EC2Launch v2 sysprep"
  & $ec2launch sysprep --shutdown=true
} else {
  # Fallback for AMIs that still ship EC2Config / EC2Launch v1.
  Write-Host "[sysprep] EC2Launch v2 not found, falling back to Sysprep directly"
  $unattend = "$env:windir\System32\Sysprep\unattend.xml"
  & "$env:windir\System32\Sysprep\Sysprep.exe" /oobe /generalize /shutdown /quiet "/unattend:$unattend"
}

Write-Host "[sysprep] generalisation triggered; instance will shut down"
