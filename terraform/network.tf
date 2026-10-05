# Network topology (confirmed design):
#   - One VPC.
#   - Public subnet:  Elastic + Attack Server (get public IPs).
#   - Private subnet: Domain Controller + Victims (no public IPs).
#   - A single NAT gateway gives the private subnet OUTBOUND internet so victims
#     can download Sysmon, Atomic Red Team, updates, and enroll the Elastic Agent.
#     NOTE: the NAT gateway adds ~$0.045/hr plus data charges. See docs/cost-and-teardown.md.

resource "aws_vpc" "lab" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = { Name = "${var.project_name}-vpc" }
}

resource "aws_internet_gateway" "lab" {
  vpc_id = aws_vpc.lab.id
  tags   = { Name = "${var.project_name}-igw" }
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.lab.id
  cidr_block              = var.public_subnet_cidr
  map_public_ip_on_launch = true

  tags = { Name = "${var.project_name}-public" }
}

resource "aws_subnet" "private" {
  vpc_id                  = aws_vpc.lab.id
  cidr_block              = var.private_subnet_cidr
  map_public_ip_on_launch = false

  tags = { Name = "${var.project_name}-private" }
}

# --- NAT gateway for private-subnet egress ---

# Only exists while var.nat_enabled is true. Parking the lab (scripts/park.ps1)
# removes the NAT, its EIP, and the private default route; the instances and
# everything configured inside them are untouched.

resource "aws_eip" "nat" {
  count  = var.nat_enabled ? 1 : 0
  domain = "vpc"
  tags   = { Name = "${var.project_name}-nat-eip" }
}

resource "aws_nat_gateway" "lab" {
  count         = var.nat_enabled ? 1 : 0
  allocation_id = aws_eip.nat[0].id
  subnet_id     = aws_subnet.public.id
  tags          = { Name = "${var.project_name}-nat" }

  depends_on = [aws_internet_gateway.lab]
}

# --- Routing ---

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.lab.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.lab.id
  }

  tags = { Name = "${var.project_name}-public-rt" }
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.lab.id
  tags   = { Name = "${var.project_name}-private-rt" }
}

# Separate resource (not an inline route) so it can come and go with the NAT.
resource "aws_route" "private_nat" {
  count                  = var.nat_enabled ? 1 : 0
  route_table_id         = aws_route_table.private.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.lab[0].id
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private" {
  subnet_id      = aws_subnet.private.id
  route_table_id = aws_route_table.private.id
}
