#!/bin/bash
set -euo pipefail

# Enable IP forwarding (required for subnet routing)
cat <<SYSCTL > /etc/sysctl.d/99-tailscale.conf
net.ipv4.ip_forward = 1
net.ipv6.conf.all.forwarding = 1
SYSCTL
sysctl -p /etc/sysctl.d/99-tailscale.conf

# Fetch Tailscale auth key from Secrets Manager
TAILSCALE_AUTH_KEY=$(aws secretsmanager get-secret-value \
  --secret-id "${tailscale_secret_arn}" \
  --region "${aws_region}" \
  --query SecretString \
  --output text)

# Install Tailscale
curl -fsSL https://tailscale.com/install.sh | sh

# Enable and start tailscaled
systemctl enable --now tailscaled

# Authenticate and advertise VPC CIDR as subnet route
tailscale up \
  --authkey="$TAILSCALE_AUTH_KEY" \
  --advertise-routes="${vpc_cidr}" \
  --accept-dns=false \
  --hostname="biomni-vpc-router"
