# Amazon Linux 2023 golden image

The Amazon Linux source (`source.amazon-ebs.amazon_linux`) is defined in the
top-level [`sources.pkr.hcl`](../sources.pkr.hcl) and provisioned by the
`linux` build in [`build.pkr.hcl`](../build.pkr.hcl).

| | |
|---|---|
| Base AMI | `al2023-ami-2023.*-x86_64` (owner alias `amazon`) |
| Login user | `ec2-user` |
| Root device | `/dev/xvda` |
| MAC | SELinux (moved to enforcing) |

The SSM Agent ships preinstalled on AL2023, so `install-agents.sh` only enables
it and installs the CloudWatch Agent.

## Amazon Linux-only tuning

[`scripts/extra-hardening.sh`](scripts/extra-hardening.sh) moves SELinux to
enforcing and documents the IMDSv2 launch-template expectation.

```bash
make amazon-linux
# or
../packer-build.sh build amazon-ebs.amazon_linux example.pkrvars.hcl
```
