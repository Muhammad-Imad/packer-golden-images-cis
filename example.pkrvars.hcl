# -----------------------------------------------------------------------------
# Example variable file. Copy to a non-committed file (e.g. dev.auto.pkrvars.hcl
# or prod.pkrvars.hcl) and adjust. All values below are public placeholders.
# -----------------------------------------------------------------------------

aws_region    = "us-east-1"
instance_type = "t3.medium"

# Build inside a private subnet and reach the builder over SSM instead of a
# public IP by uncommenting these and setting ssh_interface / associate flags.
# vpc_id              = "vpc-0123456789abcdef0"
# subnet_id           = "subnet-0123456789abcdef0"
# ssh_interface       = "session_manager"
# associate_public_ip = false

# AMI naming, encryption and distribution.
ami_prefix   = "acme-cis"
encrypt_boot = true
# kms_key_id = "arn:aws:kms:us-east-1:111111111111:key/00000000-0000-0000-0000-000000000000"

# Share the finished AMI with other org accounts and copy to extra regions.
ami_users   = ["222222222222", "333333333333"]
ami_regions = ["us-west-2"]

# CIS profile: level1_server (default) or level2_server.
cis_profile = "level1_server"

common_tags = {
  Project    = "golden-images"
  ManagedBy  = "packer"
  Compliance = "CIS"
  Owner      = "platform-engineering"
  CostCenter = "acme-platform"
}
