# ─── Required ───────────────────────────────────────────────
# Fill these in before running `terraform apply`.

# EBS snapshot containing the pre-populated data lake.
# Create it with: bash scripts/create_ebs_snapshot.sh
data_lake_snapshot_id = "snap-027e391c702b0a6cd"

# API keys — pass via CLI or environment to avoid committing secrets:
#   terraform apply -var="anthropic_api_key=sk-ant-..."
#   export TF_VAR_anthropic_api_key="sk-ant-..."
# NOTE: Do NOT set defaults here — they override TF_VAR_ env vars.

# Tailscale auth key for VPN access. Generate at:
#   https://login.tailscale.com/admin/settings/keys
# Use a reusable, ephemeral key. Pass via env to avoid committing:
#   export TF_VAR_tailscale_auth_key="tskey-auth-..."
# NOTE: Do NOT set a default here — it overrides TF_VAR_ env vars.

# ─── Optional overrides ────────────────────────────────────
# aws_region            = "us-east-1"
# environment           = "prod"
# container_image_tag   = "e1"
# biomni_llm            = "claude-sonnet-4-5"
# certificate_arn       = "arn:aws:acm:us-east-1:123456789012:certificate/..."
