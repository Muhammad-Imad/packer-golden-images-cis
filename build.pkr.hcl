// -----------------------------------------------------------------------------
// Build blocks wire each source to its provisioner chain and emit a manifest.
// Linux flow:  update -> CIS hardening -> install agents -> cleanup
// Windows flow: CIS hardening -> install agents -> sysprep
// -----------------------------------------------------------------------------

// --- Linux golden images -----------------------------------------------------
build {
  name = "linux"

  sources = [
    "source.amazon-ebs.ubuntu",
    "source.amazon-ebs.rhel",
    "source.amazon-ebs.amazon_linux",
  ]

  // 1. Patch the base OS to the latest packages.
  provisioner "shell" {
    execute_command = "sudo -E -S bash '{{ .Path }}'"
    scripts = [
      "${path.root}/scripts/update.sh",
    ]
  }

  // 2. Apply CIS hardening. CIS_PROFILE selects level1 vs level2 controls.
  provisioner "shell" {
    execute_command   = "sudo -E -S bash '{{ .Path }}'"
    expect_disconnect = true
    environment_vars = [
      "CIS_PROFILE=${var.cis_profile}",
    ]
    scripts = [
      "${path.root}/scripts/cis-hardening.sh",
    ]
  }

  // 3. Reconnect after any hardening-induced sshd reload, then install agents.
  provisioner "shell" {
    execute_command = "sudo -E -S bash '{{ .Path }}'"
    pause_before    = "10s"
    environment_vars = [
      "AWS_REGION=${var.aws_region}",
    ]
    scripts = [
      "${path.root}/scripts/install-agents.sh",
    ]
  }

  // 4. Validate the hardening with a lightweight in-image self-check.
  provisioner "shell" {
    execute_command = "sudo -E -S bash '{{ .Path }}'"
    scripts = [
      "${path.root}/scripts/validate.sh",
    ]
  }

  // 5. Strip logs, host keys, machine-id and history just before snapshot.
  provisioner "shell" {
    execute_command = "sudo -E -S bash '{{ .Path }}'"
    scripts = [
      "${path.root}/scripts/cleanup.sh",
    ]
  }

  post-processor "manifest" {
    output     = "${path.root}/manifests/linux-manifest.json"
    strip_path = true
    custom_data = {
      cis_profile = var.cis_profile
      built_at    = local.timestamp
    }
  }
}

// --- Windows golden images ---------------------------------------------------
build {
  name = "windows"

  sources = [
    "source.amazon-ebs.windows_2022",
    "source.amazon-ebs.windows_2025",
  ]

  // 1. Apply CIS hardening via PowerShell.
  provisioner "powershell" {
    environment_vars = [
      "CIS_PROFILE=${var.cis_profile}",
    ]
    scripts = [
      "${path.root}/windows/scripts/cis-hardening.ps1",
    ]
  }

  // 2. Reboot so registry/security-policy changes take effect.
  provisioner "windows-restart" {
    restart_timeout = "15m"
  }

  // 3. Install CloudWatch + SSM agents.
  provisioner "powershell" {
    environment_vars = [
      "AWS_REGION=${var.aws_region}",
    ]
    scripts = [
      "${path.root}/windows/scripts/install-agents.ps1",
    ]
  }

  // 4. Generalize the image with EC2Launch v2 sysprep so each instance gets a
  //    unique SID/computer name on first boot.
  provisioner "powershell" {
    scripts = [
      "${path.root}/windows/scripts/sysprep.ps1",
    ]
  }

  post-processor "manifest" {
    output     = "${path.root}/manifests/windows-manifest.json"
    strip_path = true
    custom_data = {
      cis_profile = var.cis_profile
      built_at    = local.timestamp
    }
  }
}
