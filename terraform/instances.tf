# The five lab machines. Terraform builds the bare servers only; you install
# and configure everything inside them by hand, following guides/.
#
# Each instance ignores AMI and user_data changes: data.tf always resolves the
# LATEST image, and without this a new AWS release would make the next
# `terraform apply` destroy and recreate a box you spent hours configuring.

# Optional SSH key pair for Linux hosts (only created if you supply a key).
resource "aws_key_pair" "lab" {
  count      = length(var.ssh_public_key) > 0 ? 1 : 0
  key_name   = "${var.project_name}-key"
  public_key = var.ssh_public_key
}

locals {
  key_name = length(var.ssh_public_key) > 0 ? aws_key_pair.lab[0].key_name : null

  # Sets the local Administrator password on first boot so you can log in via
  # SSM / RDP. See passwords.tf for the security caveat.
  windows_user_data = <<-PS
    <powershell>
    $ErrorActionPreference = "Stop"
    $pw = ConvertTo-SecureString "${random_password.windows_admin.result}" -AsPlainText -Force
    Set-LocalUser -Name "Administrator" -Password $pw
    </powershell>
  PS
}

# --- Elastic (SIEM): Elasticsearch + Kibana. Public subnet. ---
resource "aws_instance" "elastic" {
  ami                    = local.ubuntu_ami
  instance_type          = var.instance_type_elastic
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.internal.id, aws_security_group.kibana.id, aws_security_group.ssh.id]
  iam_instance_profile   = aws_iam_instance_profile.ssm.name
  key_name               = local.key_name

  root_block_device {
    volume_size = var.linux_root_volume_gb
    volume_type = "gp3"
  }

  tags = { Name = "${var.project_name}-elastic", Role = "siem" }

  lifecycle {
    ignore_changes = [ami, user_data]
  }
}

# --- Attack Server. Public subnet. ---
resource "aws_instance" "attacker" {
  ami                    = local.ubuntu_ami
  instance_type          = var.instance_type_attacker
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.internal.id, aws_security_group.ssh.id]
  iam_instance_profile   = aws_iam_instance_profile.ssm.name
  key_name               = local.key_name

  root_block_device {
    volume_size = var.linux_root_volume_gb
    volume_type = "gp3"
  }

  tags = { Name = "${var.project_name}-attacker", Role = "attacker" }

  lifecycle {
    ignore_changes = [ami, user_data]
  }
}

# --- Domain Controller. Private subnet. ---
resource "aws_instance" "dc" {
  ami                    = local.windows_ami
  instance_type          = var.instance_type_dc
  subnet_id              = aws_subnet.private.id
  vpc_security_group_ids = [aws_security_group.internal.id, aws_security_group.rdp.id]
  iam_instance_profile   = aws_iam_instance_profile.ssm.name
  key_name               = local.key_name
  user_data              = local.windows_user_data

  root_block_device {
    volume_size = var.windows_root_volume_gb
    volume_type = "gp3"
  }

  tags = { Name = "${var.project_name}-dc", Role = "domain-controller" }

  lifecycle {
    ignore_changes = [ami, user_data]
  }
}

# --- Windows Victim. Private subnet. Domain-joined by hand later. ---
resource "aws_instance" "windows_victim" {
  ami                    = local.windows_ami
  instance_type          = var.instance_type_windows_victim
  subnet_id              = aws_subnet.private.id
  vpc_security_group_ids = [aws_security_group.internal.id, aws_security_group.rdp.id]
  iam_instance_profile   = aws_iam_instance_profile.ssm.name
  key_name               = local.key_name
  user_data              = local.windows_user_data

  root_block_device {
    volume_size = var.windows_root_volume_gb
    volume_type = "gp3"
  }

  tags = { Name = "${var.project_name}-windows-victim", Role = "windows-victim" }

  lifecycle {
    ignore_changes = [ami, user_data]
  }
}

# --- Linux Victim. Private subnet. ---
resource "aws_instance" "linux_victim" {
  ami                    = local.ubuntu_ami
  instance_type          = var.instance_type_linux_victim
  subnet_id              = aws_subnet.private.id
  vpc_security_group_ids = [aws_security_group.internal.id]
  iam_instance_profile   = aws_iam_instance_profile.ssm.name
  key_name               = local.key_name

  root_block_device {
    volume_size = var.linux_root_volume_gb
    volume_type = "gp3"
  }

  tags = { Name = "${var.project_name}-linux-victim", Role = "linux-victim" }

  lifecycle {
    ignore_changes = [ami, user_data]
  }
}
