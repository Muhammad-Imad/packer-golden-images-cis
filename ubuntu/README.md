# Ubuntu 24.04 LTS golden image

The Ubuntu source (`source.amazon-ebs.ubuntu`) is defined in the top-level
[`sources.pkr.hcl`](../sources.pkr.hcl). Its provisioner chain is wired in
[`build.pkr.hcl`](../build.pkr.hcl) under the `linux` build.

| | |
|---|---|
| Base AMI | Canonical `ubuntu-noble-24.04-amd64-server-*` (owner `099720109477`) |
| Login user | `ubuntu` |
| MAC | AppArmor (enforce) |
| Firewall | `ufw` (default deny inbound, allow 22/tcp) |

## Ubuntu-only tuning

[`scripts/extra-hardening.sh`](scripts/extra-hardening.sh) adds Ubuntu-specific
controls (unattended security upgrades, AppArmor enforce, snap pruning). Add it
to the Ubuntu provisioner block when you need it.

```bash
make ubuntu                       # build only this image
# or
../packer-build.sh build amazon-ebs.ubuntu example.pkrvars.hcl
```
