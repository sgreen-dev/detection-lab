# All inputs to the lab. Copy terraform.tfvars.example to terraform.tfvars and
# set my_ip_cidr before running. Everything else has a sensible default.

variable "project_name" {
  description = "Name prefix and tag applied to all resources."
  type        = string
  default     = "detection-lab"
}

variable "aws_region" {
  description = "AWS region to build the lab in."
  type        = string
  default     = "us-east-1"
}

variable "my_ip_cidr" {
  description = "Your public IP in CIDR form (e.g. 203.0.113.5/32). This is the ONLY source allowed to reach Kibana, SSH, and RDP from the internet. Find it with: curl https://checkip.amazonaws.com"
  type        = string

  validation {
    condition     = can(cidrhost(var.my_ip_cidr, 0))
    error_message = "my_ip_cidr must be valid CIDR, e.g. 203.0.113.5/32."
  }
}

variable "vpc_cidr" {
  description = "CIDR block for the lab VPC."
  type        = string
  default     = "10.10.0.0/16"
}

variable "public_subnet_cidr" {
  description = "CIDR for the public subnet (Elastic + Attack Server)."
  type        = string
  default     = "10.10.1.0/24"
}

variable "private_subnet_cidr" {
  description = "CIDR for the private subnet (Domain Controller + Victims)."
  type        = string
  default     = "10.10.2.0/24"
}

variable "nat_enabled" {
  description = "Whether the NAT gateway exists. The NAT bills ~$0.045/hr even when every instance is stopped, so scripts/park.ps1 sets this to false between sessions and scripts/unpark.ps1 sets it back to true."
  type        = bool
  default     = true
}

variable "ssh_public_key" {
  description = "Optional OpenSSH public key for SSH to Linux hosts. Leave empty to rely solely on SSM Session Manager (recommended)."
  type        = string
  default     = ""
}

# --- Instance sizes. Defaults match the confirmed design and cost table. ---

variable "instance_type_elastic" {
  description = "Elastic (Elasticsearch + Kibana) node. Needs ~8 GB RAM."
  type        = string
  default     = "t3.large"
}

variable "instance_type_dc" {
  description = "Domain Controller."
  type        = string
  default     = "t3.medium"
}

variable "instance_type_windows_victim" {
  description = "Windows Victim."
  type        = string
  default     = "t3.medium"
}

variable "instance_type_linux_victim" {
  description = "Linux Victim."
  type        = string
  default     = "t3.small"
}

variable "instance_type_attacker" {
  description = "Attack Server."
  type        = string
  default     = "t3.medium"
}

variable "windows_root_volume_gb" {
  description = "Root EBS size for Windows hosts."
  type        = number
  default     = 50
}

variable "linux_root_volume_gb" {
  description = "Root EBS size for Linux hosts. Elastic needs headroom for indices."
  type        = number
  default     = 40
}
