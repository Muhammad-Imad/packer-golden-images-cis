# -----------------------------------------------------------------------------
# cis-hardening.ps1 — apply a representative subset of CIS Microsoft Windows
# Server 2022/2025 Benchmark controls.
#
# ORIGINAL, distilled implementation for demonstration. It is NOT a substitute
# for an audited CIS GPO baseline — validate the result with a scanner
# (e.g. the CIS-CAT tool) and tune to your organisation's policy.
#
# Honours $env:CIS_PROFILE = level1_server (default) or level2_server.
# -----------------------------------------------------------------------------
$ErrorActionPreference = "Stop"
$profileName = if ($env:CIS_PROFILE) { $env:CIS_PROFILE } else { "level1_server" }
Write-Host "[cis] applying profile: $profileName"

function Set-Reg {
  param([string]$Path, [string]$Name, $Value, [string]$Type = "DWord")
  if (-not (Test-Path $Path)) { New-Item -Path $Path -Force | Out-Null }
  New-ItemProperty -Path $Path -Name $Name -Value $Value -PropertyType $Type -Force | Out-Null
}

# -----------------------------------------------------------------------------
# 1. Account & password policy (CIS 1.1.x / 1.2.x)
# -----------------------------------------------------------------------------
Write-Host "[cis] 1. account and password policy"
net accounts /minpwlen:14 /maxpwage:365 /minpwage:1 /uniquepw:24 | Out-Null
net accounts /lockoutthreshold:5 /lockoutduration:15 /lockoutwindow:15 | Out-Null
# Enforce password complexity via the local security policy export/import.
$secCfg = "$env:TEMP\secpol.cfg"
secedit /export /cfg $secCfg | Out-Null
(Get-Content $secCfg) `
  -replace 'PasswordComplexity = \d', 'PasswordComplexity = 1' `
  -replace 'ClearTextPassword = \d', 'ClearTextPassword = 0' |
  Set-Content $secCfg
secedit /configure /db "$env:windir\security\local.sdb" /cfg $secCfg /areas SECURITYPOLICY | Out-Null
Remove-Item $secCfg -Force -ErrorAction SilentlyContinue

# -----------------------------------------------------------------------------
# 2. Disable insecure protocols & legacy crypto (CIS 18.x / network)
# -----------------------------------------------------------------------------
Write-Host "[cis] 2. disabling SMBv1, LLMNR, NetBIOS and weak TLS/ciphers"
Disable-WindowsOptionalFeature -Online -FeatureName SMB1Protocol -NoRestart -ErrorAction SilentlyContinue | Out-Null
Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters" "SMB1" 0
# Disable LLMNR
Set-Reg "HKLM:\Software\Policies\Microsoft\Windows NT\DNSClient" "EnableMulticast" 0
# Require SMB signing
Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters" "RequireSecuritySignature" 1
Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Services\LanmanWorkstation\Parameters" "RequireSecuritySignature" 1

# Disable SSL 2.0/3.0 and TLS 1.0/1.1 server protocols.
$protoBase = "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols"
foreach ($proto in @("SSL 2.0","SSL 3.0","TLS 1.0","TLS 1.1")) {
  Set-Reg "$protoBase\$proto\Server" "Enabled" 0
  Set-Reg "$protoBase\$proto\Server" "DisabledByDefault" 1
}
Set-Reg "$protoBase\TLS 1.2\Server" "Enabled" 1
Set-Reg "$protoBase\TLS 1.2\Server" "DisabledByDefault" 0

# -----------------------------------------------------------------------------
# 3. User Account Control / interactive logon (CIS 2.3.x)
# -----------------------------------------------------------------------------
Write-Host "[cis] 3. UAC and interactive logon hardening"
$polSys = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System"
Set-Reg $polSys "EnableLUA" 1
Set-Reg $polSys "ConsentPromptBehaviorAdmin" 2
Set-Reg $polSys "PromptOnSecureDesktop" 1
Set-Reg $polSys "FilterAdministratorToken" 1
# Do not display last signed-in user, require Ctrl-Alt-Del.
Set-Reg $polSys "DontDisplayLastUserName" 1
Set-Reg $polSys "DisableCAD" 0
# Legal notice banner.
Set-Reg $polSys "LegalNoticeCaption" "Authorized Use Only" "String"
Set-Reg $polSys "LegalNoticeText" "Authorized uses only. All activity may be monitored and reported." "String"
# Disable auto-run on all drives.
Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer" "NoDriveTypeAutoRun" 255

# -----------------------------------------------------------------------------
# 4. Windows Firewall — default-deny inbound on all profiles (CIS 9.x)
# -----------------------------------------------------------------------------
Write-Host "[cis] 4. enabling Windows Firewall on all profiles"
Set-NetFirewallProfile -Profile Domain,Public,Private `
  -Enabled True -DefaultInboundAction Block -DefaultOutboundAction Allow `
  -LogAllowed False -LogBlocked True

# -----------------------------------------------------------------------------
# 5. Advanced audit policy (CIS 17.x)
# -----------------------------------------------------------------------------
Write-Host "[cis] 5. enabling advanced audit policy"
$auditCategories = @(
  "Logon/Logoff","Account Logon","Account Management",
  "Policy Change","Privilege Use","System","DS Access"
)
foreach ($cat in $auditCategories) {
  auditpol /set /category:"$cat" /success:enable /failure:enable | Out-Null
}
# Force advanced audit policy to override legacy settings.
Set-Reg $polSys "SCENoApplyLegacyAuditPolicy" 1

# -----------------------------------------------------------------------------
# 6. Disable unneeded services (CIS 5.x)
# -----------------------------------------------------------------------------
Write-Host "[cis] 6. disabling unneeded services"
$disableServices = @(
  "RemoteRegistry","Telnet","SNMPTRAP","Spooler",
  "WMPNetworkSvc","XblAuthManager","XblGameSave","SharedAccess"
)
foreach ($svc in $disableServices) {
  $s = Get-Service -Name $svc -ErrorAction SilentlyContinue
  if ($s) {
    Stop-Service  -Name $svc -Force -ErrorAction SilentlyContinue
    Set-Service   -Name $svc -StartupType Disabled -ErrorAction SilentlyContinue
  }
}

# -----------------------------------------------------------------------------
# 7. Windows Defender / RDP hardening
# -----------------------------------------------------------------------------
Write-Host "[cis] 7. Defender and RDP hardening"
if (Get-Command Set-MpPreference -ErrorAction SilentlyContinue) {
  Set-MpPreference -MAPSReporting Advanced -SubmitSamplesConsent SendAllSamples `
    -DisableRealtimeMonitoring $false -ErrorAction SilentlyContinue
}
# Require NLA for RDP and force high encryption.
$rdpTcp = "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp"
Set-Reg $rdpTcp "UserAuthentication" 1
Set-Reg $rdpTcp "MinEncryptionLevel" 3
Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server" "fDenyTSConnections" 0

# -----------------------------------------------------------------------------
# 8. Level 2 — additional restrictive controls
# -----------------------------------------------------------------------------
if ($profileName -eq "level2_server") {
  Write-Host "[cis] 8. applying level2 additional controls"
  # Disable Windows Script Host.
  Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows Script Host\Settings" "Enabled" 0
  # Restrict anonymous enumeration of SAM accounts and shares.
  Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa" "RestrictAnonymous" 1
  Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa" "RestrictAnonymousSAM" 1
  # Enable PowerShell script-block logging.
  Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ScriptBlockLogging" "EnableScriptBlockLogging" 1
}

Write-Host "[cis] hardening complete for profile $profileName"
