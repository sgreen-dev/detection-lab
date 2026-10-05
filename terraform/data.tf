# AMI lookups via AWS-published SSM public parameters. These always resolve to
# the current official image, so we never hard-code a stale AMI ID. To PIN the
# lab to a known-good image, copy the resolved IDs from `terraform output` into
# ../versions.yml and note the date.

# Ubuntu 22.04 LTS (Jammy), amd64, published by Canonical (owner 099720109477).
# Looked up via EC2 describe-images instead of Canonical's SSM public
# parameters, which do not reliably resolve in every account/region.
data "aws_ami" "ubuntu_2204" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Windows Server 2022, English, Full (Desktop Experience), published by AWS.
data "aws_ssm_parameter" "windows_2022" {
  name = "/aws/service/ami-windows-latest/Windows_Server-2022-English-Full-Base"
}

locals {
  ubuntu_ami  = data.aws_ami.ubuntu_2204.id
  windows_ami = nonsensitive(data.aws_ssm_parameter.windows_2022.value)
}
