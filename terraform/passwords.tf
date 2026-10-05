# Randomly generated credentials, stored as SecureString parameters in SSM
# Parameter Store. Nothing sensitive is committed to git; you read these back
# with the AWS CLI (see outputs.tf for the exact commands).
#
# NOTE: the Windows local Administrator password is also passed via user_data to
# set the account on first boot. user_data is visible to anyone who can read the
# instance metadata/console, so treat this as a LAB credential, never reuse it.

resource "random_password" "windows_admin" {
  length           = 20
  special          = true
  override_special = "!@#$%^&*()-_=+"
  min_lower        = 2
  min_upper        = 2
  min_numeric      = 2
  min_special      = 2
}

resource "random_password" "domain_admin" {
  length           = 20
  special          = true
  override_special = "!@#$%^&*()-_=+"
  min_lower        = 2
  min_upper        = 2
  min_numeric      = 2
  min_special      = 2
}

resource "random_password" "dsrm" {
  length           = 20
  special          = true
  override_special = "!@#$%^&*()-_=+"
  min_lower        = 2
  min_upper        = 2
  min_numeric      = 2
  min_special      = 2
}

resource "aws_ssm_parameter" "windows_admin" {
  name        = "/${var.project_name}/windows_admin_password"
  description = "Local Administrator password for Windows hosts"
  type        = "SecureString"
  value       = random_password.windows_admin.result
  overwrite   = true
  tags        = { Name = "${var.project_name}-windows-admin" }
}

resource "aws_ssm_parameter" "domain_admin" {
  name        = "/${var.project_name}/domain_admin_password"
  description = "Intended password for the seeded domain admin (used in the AD Build Guide)"
  type        = "SecureString"
  value       = random_password.domain_admin.result
  overwrite   = true
  tags        = { Name = "${var.project_name}-domain-admin" }
}

resource "aws_ssm_parameter" "dsrm" {
  name        = "/${var.project_name}/dsrm_password"
  description = "Directory Services Restore Mode password (used when promoting the DC)"
  type        = "SecureString"
  value       = random_password.dsrm.result
  overwrite   = true
  tags        = { Name = "${var.project_name}-dsrm" }
}
