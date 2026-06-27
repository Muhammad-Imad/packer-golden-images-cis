# Windows Server 2022 / 2025 golden images

The Windows sources (`source.amazon-ebs.windows_2022` and
`source.amazon-ebs.windows_2025`) are defined in the top-level
[`sources.pkr.hcl`](../sources.pkr.hcl) and provisioned by the `windows` build
in [`build.pkr.hcl`](../build.pkr.hcl).

| | |
|---|---|
| Base AMI | `Windows_Server-20{22,25}-English-Full-Base-*` (owner alias `amazon`) |
| Communicator | WinRM over HTTPS (5986) |
| Generalisation | EC2Launch v2 sysprep |

## Provisioner chain

1. [`scripts/bootstrap-winrm.ps1`](scripts/bootstrap-winrm.ps1) — EC2 user-data
   that stands up a short-lived WinRM HTTPS listener with a self-signed cert so
   Packer can connect. The cert and listener are removed during sysprep.
2. [`scripts/cis-hardening.ps1`](scripts/cis-hardening.ps1) — CIS controls:
   password/lockout policy, SMBv1 off, TLS hardening, UAC, firewall, audit
   policy, service disabling, RDP NLA.
3. `windows-restart` — reboot so policy/registry changes apply.
4. [`scripts/install-agents.ps1`](scripts/install-agents.ps1) — SSM + CloudWatch
   agents.
5. [`scripts/sysprep.ps1`](scripts/sysprep.ps1) — scrub build artifacts, clear
   event logs, then generalise via EC2Launch v2 and shut down.

```bash
make windows
# or
../packer-build.sh build windows.windows_2022 example.pkrvars.hcl
```

> Note: the WinRM listener uses a self-signed certificate **for the build only**
> (`winrm_insecure = true`). It never ships in the produced AMI.
