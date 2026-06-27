# Red Hat Enterprise Linux 9 golden image

The RHEL source (`source.amazon-ebs.rhel`) is defined in the top-level
[`sources.pkr.hcl`](../sources.pkr.hcl) and provisioned by the `linux` build in
[`build.pkr.hcl`](../build.pkr.hcl).

| | |
|---|---|
| Base AMI | `RHEL-9.*_HVM-*-x86_64-*-Hourly2-GP3` (owner `309956199498`) |
| Login user | `ec2-user` |
| MAC | SELinux (enforcing, targeted) |
| Firewall | `firewalld` (default zone `drop`, ssh allowed) |

## RHEL-only tuning

[`scripts/extra-hardening.sh`](scripts/extra-hardening.sh) adds a
SHA1-restricted crypto policy, SELinux enforcing, and `dnf-automatic` security
patching.

```bash
make rhel
# or
../packer-build.sh build amazon-ebs.rhel example.pkrvars.hcl
```
