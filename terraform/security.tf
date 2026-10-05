# Security groups. Principle: nothing from the internet except from YOUR ip
# (my_ip_cidr). Everything inside the VPC can talk freely so attacks and
# telemetry flow like a real network.

# Attached to every host: allow all traffic between lab machines, allow all egress.
resource "aws_security_group" "internal" {
  name        = "${var.project_name}-internal"
  description = "Intra-VPC traffic + egress for all lab hosts"
  vpc_id      = aws_vpc.lab.id

  ingress {
    description = "All traffic within the lab VPC"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project_name}-internal" }
}

# Kibana + Elasticsearch reachable only from your IP.
resource "aws_security_group" "kibana" {
  name        = "${var.project_name}-kibana"
  description = "Kibana/Elasticsearch access from my_ip only"
  vpc_id      = aws_vpc.lab.id

  ingress {
    description = "Kibana UI"
    from_port   = 5601
    to_port     = 5601
    protocol    = "tcp"
    cidr_blocks = [var.my_ip_cidr]
  }

  ingress {
    description = "Elasticsearch API"
    from_port   = 9200
    to_port     = 9200
    protocol    = "tcp"
    cidr_blocks = [var.my_ip_cidr]
  }

  tags = { Name = "${var.project_name}-kibana" }
}

# SSH from your IP (SSM Session Manager is the primary path; this is a fallback).
resource "aws_security_group" "ssh" {
  name        = "${var.project_name}-ssh"
  description = "SSH from my_ip only"
  vpc_id      = aws_vpc.lab.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.my_ip_cidr]
  }

  tags = { Name = "${var.project_name}-ssh" }
}

# RDP from your IP (SSM Session Manager also works without opening this).
resource "aws_security_group" "rdp" {
  name        = "${var.project_name}-rdp"
  description = "RDP from my_ip only"
  vpc_id      = aws_vpc.lab.id

  ingress {
    description = "RDP"
    from_port   = 3389
    to_port     = 3389
    protocol    = "tcp"
    cidr_blocks = [var.my_ip_cidr]
  }

  tags = { Name = "${var.project_name}-rdp" }
}
