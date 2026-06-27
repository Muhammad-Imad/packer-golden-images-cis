// -----------------------------------------------------------------------------
// amazon-ebs source blocks, one per target operating system.
// Each source looks up the most-recent upstream base AMI and registers a
// hardened output AMI with an encrypted root volume.
// -----------------------------------------------------------------------------

locals {
  timestamp = formatdate("YYYYMMDD-hhmmss", timestamp())

  // Tags merged onto every AMI / snapshot.
  ami_tags = merge(var.common_tags, {
    CISProfile = var.cis_profile
    BuiltAt    = local.timestamp
    BuiltBy    = "packer-golden-images-cis"
  })

  // Run tags applied to the ephemeral builder instance only.
  run_tags = merge(var.common_tags, {
    Name = "packer-builder-${local.timestamp}"
  })
}

// --- Ubuntu 24.04 LTS (Noble Numbat) ----------------------------------------
source "amazon-ebs" "ubuntu" {
  region        = var.aws_region
  instance_type = var.instance_type
  subnet_id     = var.subnet_id != "" ? var.subnet_id : null
  vpc_id        = var.vpc_id != "" ? var.vpc_id : null

  associate_public_ip_address = var.associate_public_ip
  ssh_interface               = var.ssh_interface
  ssh_username                = "ubuntu"

  ami_name        = "${var.ami_prefix}-ubuntu-24.04-${local.timestamp}"
  ami_description = "CIS-hardened Ubuntu 24.04 LTS golden image (${var.cis_profile})."
  ami_users       = var.ami_users
  ami_regions     = var.ami_regions

  encrypt_boot = var.encrypt_boot
  kms_key_id   = var.kms_key_id != "" ? var.kms_key_id : null

  source_ami_filter {
    filters = {
      name                = "ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"
      root-device-type    = "ebs"
      virtualization-type = "hvm"
    }
    owners      = [var.ubuntu_owner]
    most_recent = true
  }

  launch_block_device_mappings {
    device_name           = "/dev/sda1"
    volume_size           = 20
    volume_type           = "gp3"
    delete_on_termination = true
    encrypted             = var.encrypt_boot
  }

  run_tags         = local.run_tags
  run_volume_tags  = local.run_tags
  tags             = local.ami_tags
  snapshot_tags    = local.ami_tags
}

// --- Red Hat Enterprise Linux 9 ----------------------------------------------
source "amazon-ebs" "rhel" {
  region        = var.aws_region
  instance_type = var.instance_type
  subnet_id     = var.subnet_id != "" ? var.subnet_id : null
  vpc_id        = var.vpc_id != "" ? var.vpc_id : null

  associate_public_ip_address = var.associate_public_ip
  ssh_interface               = var.ssh_interface
  ssh_username                = "ec2-user"

  ami_name        = "${var.ami_prefix}-rhel-9-${local.timestamp}"
  ami_description = "CIS-hardened Red Hat Enterprise Linux 9 golden image (${var.cis_profile})."
  ami_users       = var.ami_users
  ami_regions     = var.ami_regions

  encrypt_boot = var.encrypt_boot
  kms_key_id   = var.kms_key_id != "" ? var.kms_key_id : null

  source_ami_filter {
    filters = {
      name                = "RHEL-9.*_HVM-*-x86_64-*-Hourly2-GP3"
      root-device-type    = "ebs"
      virtualization-type = "hvm"
    }
    owners      = [var.rhel_owner]
    most_recent = true
  }

  launch_block_device_mappings {
    device_name           = "/dev/sda1"
    volume_size           = 20
    volume_type           = "gp3"
    delete_on_termination = true
    encrypted             = var.encrypt_boot
  }

  run_tags        = local.run_tags
  run_volume_tags = local.run_tags
  tags            = local.ami_tags
  snapshot_tags   = local.ami_tags
}

// --- Amazon Linux 2023 -------------------------------------------------------
source "amazon-ebs" "amazon_linux" {
  region        = var.aws_region
  instance_type = var.instance_type
  subnet_id     = var.subnet_id != "" ? var.subnet_id : null
  vpc_id        = var.vpc_id != "" ? var.vpc_id : null

  associate_public_ip_address = var.associate_public_ip
  ssh_interface               = var.ssh_interface
  ssh_username                = "ec2-user"

  ami_name        = "${var.ami_prefix}-al2023-${local.timestamp}"
  ami_description = "CIS-hardened Amazon Linux 2023 golden image (${var.cis_profile})."
  ami_users       = var.ami_users
  ami_regions     = var.ami_regions

  encrypt_boot = var.encrypt_boot
  kms_key_id   = var.kms_key_id != "" ? var.kms_key_id : null

  source_ami_filter {
    filters = {
      name                = "al2023-ami-2023.*-x86_64"
      root-device-type    = "ebs"
      virtualization-type = "hvm"
    }
    owners      = [var.amazon_owner]
    most_recent = true
  }

  launch_block_device_mappings {
    device_name           = "/dev/xvda"
    volume_size           = 20
    volume_type           = "gp3"
    delete_on_termination = true
    encrypted             = var.encrypt_boot
  }

  run_tags        = local.run_tags
  run_volume_tags = local.run_tags
  tags            = local.ami_tags
  snapshot_tags   = local.ami_tags
}

// --- Windows Server 2022 -----------------------------------------------------
source "amazon-ebs" "windows_2022" {
  region        = var.aws_region
  instance_type = var.windows_instance_type
  subnet_id     = var.subnet_id != "" ? var.subnet_id : null
  vpc_id        = var.vpc_id != "" ? var.vpc_id : null

  associate_public_ip_address = var.associate_public_ip

  // WinRM is provisioned through a bootstrap userdata script that enables the
  // service on first boot; Packer then connects over WinRM/HTTPS.
  communicator   = "winrm"
  winrm_username = "Administrator"
  winrm_insecure = true
  winrm_use_ssl  = true
  user_data_file = "${path.root}/windows/scripts/bootstrap-winrm.ps1"

  ami_name        = "${var.ami_prefix}-windows-2022-${local.timestamp}"
  ami_description = "CIS-hardened Windows Server 2022 golden image (${var.cis_profile})."
  ami_users       = var.ami_users
  ami_regions     = var.ami_regions

  encrypt_boot = var.encrypt_boot
  kms_key_id   = var.kms_key_id != "" ? var.kms_key_id : null

  source_ami_filter {
    filters = {
      name                = "Windows_Server-2022-English-Full-Base-*"
      root-device-type    = "ebs"
      virtualization-type = "hvm"
    }
    owners      = [var.windows_owner]
    most_recent = true
  }

  launch_block_device_mappings {
    device_name           = "/dev/sda1"
    volume_size           = 50
    volume_type           = "gp3"
    delete_on_termination = true
    encrypted             = var.encrypt_boot
  }

  run_tags        = local.run_tags
  run_volume_tags = local.run_tags
  tags            = local.ami_tags
  snapshot_tags   = local.ami_tags
}

// --- Windows Server 2025 -----------------------------------------------------
source "amazon-ebs" "windows_2025" {
  region        = var.aws_region
  instance_type = var.windows_instance_type
  subnet_id     = var.subnet_id != "" ? var.subnet_id : null
  vpc_id        = var.vpc_id != "" ? var.vpc_id : null

  associate_public_ip_address = var.associate_public_ip

  communicator   = "winrm"
  winrm_username = "Administrator"
  winrm_insecure = true
  winrm_use_ssl  = true
  user_data_file = "${path.root}/windows/scripts/bootstrap-winrm.ps1"

  ami_name        = "${var.ami_prefix}-windows-2025-${local.timestamp}"
  ami_description = "CIS-hardened Windows Server 2025 golden image (${var.cis_profile})."
  ami_users       = var.ami_users
  ami_regions     = var.ami_regions

  encrypt_boot = var.encrypt_boot
  kms_key_id   = var.kms_key_id != "" ? var.kms_key_id : null

  source_ami_filter {
    filters = {
      name                = "Windows_Server-2025-English-Full-Base-*"
      root-device-type    = "ebs"
      virtualization-type = "hvm"
    }
    owners      = [var.windows_owner]
    most_recent = true
  }

  launch_block_device_mappings {
    device_name           = "/dev/sda1"
    volume_size           = 50
    volume_type           = "gp3"
    delete_on_termination = true
    encrypted             = var.encrypt_boot
  }

  run_tags        = local.run_tags
  run_volume_tags = local.run_tags
  tags            = local.ami_tags
  snapshot_tags   = local.ami_tags
}
