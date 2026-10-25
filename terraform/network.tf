resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags                 = { Name = "juice-shop-vpc" }
}

resource "aws_subnet" "public_a" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "eu-central-1a"
  map_public_ip_on_launch = false
  tags                    = { Name = "juice-shop-public-a" }
}

resource "aws_subnet" "public_b" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "eu-central-1b"
  map_public_ip_on_launch = false
  tags                    = { Name = "juice-shop-public-b" }
}

resource "aws_subnet" "private_a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.11.0/24"
  availability_zone = "eu-central-1a"
  tags              = { Name = "juice-shop-private-a" }
}

resource "aws_subnet" "private_b" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.12.0/24"
  availability_zone = "eu-central-1b"
  tags              = { Name = "juice-shop-private-b" }
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }
}

resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.public_a.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "b" {
  subnet_id      = aws_subnet.public_b.id
  route_table_id = aws_route_table.public.id
}

resource "aws_eip" "nat" {
  domain = "vpc"
  tags   = { Name = "juice-shop-nat" }
}

# One NAT gateway keeps this lab simple. It is billed while provisioned and
# is a single point of failure for outbound access from both private subnets.
resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public_a.id
  depends_on    = [aws_internet_gateway.gw]
  tags          = { Name = "juice-shop-nat" }
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id
  }
}

resource "aws_route_table_association" "private_a" {
  subnet_id      = aws_subnet.private_a.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "private_b" {
  subnet_id      = aws_subnet.private_b.id
  route_table_id = aws_route_table.private.id
}

resource "aws_security_group" "alb_sg" {
  name_prefix = "juice-shop-alb-"
  description = "Public entry point for the WAF-protected lab"
  vpc_id      = aws_vpc.main.id

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group" "ecs_sg" {
  name_prefix = "juice-shop-ecs-"
  description = "Juice Shop accepts requests only from the ALB"
  vpc_id      = aws_vpc.main.id

  lifecycle {
    create_before_destroy = true
  }
}

# Separate rule resources avoid circular group references and make tfsec's
# port-scoped exceptions effective. This rule type is supported by tfsec 1.28.14.
# Public HTTP is intentional for this domain-free lab; see README.md.
#tfsec:ignore:aws-ec2-no-public-ingress-sgr[from_port=80]
resource "aws_security_group_rule" "alb_http" {
  type              = "ingress"
  security_group_id = aws_security_group.alb_sg.id
  description       = "Public HTTP; HTTPS requires a domain and ACM certificate"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "alb_to_ecs" {
  type                     = "egress"
  security_group_id        = aws_security_group.alb_sg.id
  source_security_group_id = aws_security_group.ecs_sg.id
  description              = "ALB requests and health checks to Juice Shop only"
  from_port                = 3000
  to_port                  = 3000
  protocol                 = "tcp"
}

resource "aws_security_group_rule" "ecs_from_alb" {
  type                     = "ingress"
  security_group_id        = aws_security_group.ecs_sg.id
  source_security_group_id = aws_security_group.alb_sg.id
  description              = "Application traffic from ALB only"
  from_port                = 3000
  to_port                  = 3000
  protocol                 = "tcp"
}

# Docker Hub and CloudWatch use changing public addresses. Limit egress to TLS
# through NAT; this is not an exfiltration-proof destination allowlist.
#tfsec:ignore:aws-ec2-no-public-egress-sgr[from_port=443]
resource "aws_security_group_rule" "ecs_https" {
  type              = "egress"
  security_group_id = aws_security_group.ecs_sg.id
  description       = "HTTPS for image pulls and CloudWatch Logs through NAT"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
}
