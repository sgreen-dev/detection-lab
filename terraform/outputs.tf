# Everything you need after `terraform apply`: addresses, the Kibana URL, and
# the exact commands to read back generated passwords and open sessions.

output "kibana_url" {
  description = "Open this from the machine whose IP is my_ip_cidr. Kibana serves HTTP by default; for a secure path use SSM port-forwarding instead (see guides/01-elastic.md)."
  value       = "http://${aws_instance.elastic.public_ip}:5601"
}

output "elastic_public_ip" {
  value = aws_instance.elastic.public_ip
}

output "elastic_private_ip" {
  description = "Point Elastic Agents at this address from inside the lab."
  value       = aws_instance.elastic.private_ip
}

output "attacker_public_ip" {
  value = aws_instance.attacker.public_ip
}

output "private_ips" {
  description = "Private addresses of the domain and victim hosts."
  value = {
    dc             = aws_instance.dc.private_ip
    windows_victim = aws_instance.windows_victim.private_ip
    linux_victim   = aws_instance.linux_victim.private_ip
  }
}

output "aws_region" {
  description = "Read by scripts/park.ps1 and scripts/unpark.ps1."
  value       = var.aws_region
}

output "instance_ids" {
  description = "Use these with `aws ssm start-session --target <id>`."
  value = {
    elastic        = aws_instance.elastic.id
    attacker       = aws_instance.attacker.id
    dc             = aws_instance.dc.id
    windows_victim = aws_instance.windows_victim.id
    linux_victim   = aws_instance.linux_victim.id
  }
}

output "amis_used" {
  description = "Resolved AMI IDs. Copy into ../versions.yml to pin a known-good build."
  value = {
    ubuntu_2204  = local.ubuntu_ami
    windows_2022 = local.windows_ami
  }
}

output "get_windows_password_command" {
  description = "Run this (AWS CLI) to reveal the local Administrator password."
  value       = "aws ssm get-parameter --name /${var.project_name}/windows_admin_password --with-decryption --query Parameter.Value --output text --region ${var.aws_region}"
}

output "get_domain_admin_password_command" {
  value = "aws ssm get-parameter --name /${var.project_name}/domain_admin_password --with-decryption --query Parameter.Value --output text --region ${var.aws_region}"
}

output "get_dsrm_password_command" {
  value = "aws ssm get-parameter --name /${var.project_name}/dsrm_password --with-decryption --query Parameter.Value --output text --region ${var.aws_region}"
}

output "start_session_examples" {
  description = "Open an interactive session without opening any inbound port."
  value = {
    linux_victim   = "aws ssm start-session --target ${aws_instance.linux_victim.id} --region ${var.aws_region}"
    windows_victim = "aws ssm start-session --target ${aws_instance.windows_victim.id} --region ${var.aws_region}"
  }
}
