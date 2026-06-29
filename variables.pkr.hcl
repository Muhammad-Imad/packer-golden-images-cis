// -----------------------------------------------------------------------------
// Input variables for the CIS golden-image bakery.
// All defaults are safe, public placeholders (account 111111111111, region
// us-east-1, org "acme"). Override per environment with a *.pkrvars.hcl file.
// -----------------------------------------------------------------------------

variable "aws_region" {
  type        = string
  default     = "us-east-1"
  description = "AWS region in which the build instances are launched and AMIs registered."
}

variable "instance_type" {
  type        = string
  default     = "t3.medium"
  description = "Instance type used for the ephemeral builder instance (Linux)."
}

variable "windows_instance_type" {
  type        = string
  default     = "t3.large"
  description = "Instance type used for the ephemeral builder instance (Windows)."
}

variable "subnet_id" {
  type        = string
  default     = ""
  description = "Optional subnet to launch the builder in. Empty lets AWS pick a default-VPC subnet."
}

variable "vpc_id" {
  type        = string
  default     = ""
  description = "Optional VPC for the builder instance and temporary security group."
}

variable "ssh_interface" {
  type        = string
  default     = "public_ip"
  description = "How Packer reaches the Linux builder: public_ip, private_ip, or session_manager."
}

variable "associate_public_ip" {
  type        = bool
  default     = true
  description = "Associate a public IP with the builder. Set false when building inside a private subnet via SSM."
}

variable "encrypt_boot" {
  type        = bool
  default     = true
  description = "Encrypt the resulting AMI's root volume."
}

variable "kms_key_id" {
  type        = string
  default     = ""
  description = "Optional KMS key ARN for AMI encryption. Empty uses the account's default EBS key."
}

variable "ami_prefix" {
  type        = string
  default     = "acme-cis"
  description = "Prefix applied to every produced AMI name, e.g. acme-cis-ubuntu-24.04-<timestamp>."
}

variable "ami_users" {
  type        = list(string)
  default     = []
  description = "Account IDs the AMI is shared with, e.g. [\"222222222222\", \"333333333333\"]."
}

variable "ami_regions" {
  type        = list(string)
  default     = []
  description = "Additional regions to copy the AMI to after the build, e.g. [\"us-west-2\"]."
}

variable "cis_profile" {
  type        = string
  default     = "level1_server"
  description = "Target CIS Benchmark profile. One of level1_server or level2_server."

  validation {
    condition     = contains(["level1_server", "level2_server"], var.cis_profile)
    error_message = "cis_profile must be either level1_server or level2_server."
  }
}

variable "common_tags" {
  type = map(string)
  default = {
    Project    = "golden-images"
    ManagedBy  = "packer"
    Compliance = "CIS"
    Owner      = "platform-engineering"
  }
  description = "Tags applied to the AMI, snapshots, and the builder instance."
}

// Source-AMI owner/filter knobs. Defaults track the canonical upstream owners.
variable "ubuntu_owner" {
  type        = string
  default     = "099720109477" // Canonical
  description = "Owner account ID for the Ubuntu source AMI lookup."
}

variable "rhel_owner" {
  type        = string
  default     = "309956199498" // Red Hat
  description = "Owner account ID for the RHEL source AMI lookup."
}

variable "amazon_owner" {
  type        = string
  default     = "amazon"
  description = "Owner alias for the Amazon Linux source AMI lookup."
}

variable "windows_owner" {
  type        = string
  default     = "amazon"
  description = "Owner alias for the Windows Server source AMI lookup."
}
