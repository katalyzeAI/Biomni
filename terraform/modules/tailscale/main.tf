locals {
  name_prefix = "${var.project_name}-${var.environment}"
}

# ──── AMI (Amazon Linux 2023) ──────────────────────────────

data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# ──── Security Group ───────────────────────────────────────
# Tailscale uses outbound-only connections (WireGuard/DERP).
# No inbound ports needed — not even SSH (use SSM instead).

resource "aws_security_group" "tailscale" {
  name_prefix = "${local.name_prefix}-tailscale-"
  vpc_id      = var.vpc_id
  description = "Tailscale subnet router - outbound only"

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${local.name_prefix}-tailscale-sg" }

  lifecycle { create_before_destroy = true }
}

# ──── IAM Role (SSM + Secrets Manager access) ─────────────

resource "aws_iam_role" "tailscale" {
  name = "${local.name_prefix}-tailscale"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })

  tags = { Name = "${local.name_prefix}-tailscale-role" }
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.tailscale.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy" "secrets_read" {
  name = "${local.name_prefix}-tailscale-secrets"
  role = aws_iam_role.tailscale.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "secretsmanager:GetSecretValue"
      Resource = var.tailscale_auth_key_arn
    }]
  })
}

resource "aws_iam_instance_profile" "tailscale" {
  name = "${local.name_prefix}-tailscale"
  role = aws_iam_role.tailscale.name
}

# ──── EC2 Instance ─────────────────────────────────────────

resource "aws_instance" "router" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = var.instance_type
  subnet_id              = var.subnet_id
  vpc_security_group_ids = [aws_security_group.tailscale.id]
  iam_instance_profile   = aws_iam_instance_profile.tailscale.name

  # Required for routing — instance forwards packets for other VPC IPs
  source_dest_check = false

  user_data = templatefile("${path.module}/user_data.sh", {
    tailscale_secret_arn = var.tailscale_auth_key_arn
    aws_region           = var.aws_region
    vpc_cidr             = var.vpc_cidr
  })

  tags = { Name = "${local.name_prefix}-tailscale-router" }
}
