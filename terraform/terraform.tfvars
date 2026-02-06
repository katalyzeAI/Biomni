# ─── Required ───────────────────────────────────────────────
# Fill these in before running `terraform apply`.

# EBS snapshot containing the pre-populated data lake.
# Create it with: bash scripts/create_ebs_snapshot.sh
data_lake_snapshot_id = "snap-REPLACE_ME"

# API keys — pass via CLI or environment to avoid committing secrets:
#   terraform apply -var="anthropic_api_key=sk-ant-..."
#   export TF_VAR_anthropic_api_key="sk-ant-..."
anthropic_api_key = ""
openai_api_key    = ""

# ─── Optional overrides ────────────────────────────────────
# aws_region            = "us-east-1"
# environment           = "prod"
# container_image_tag   = "e1"
# biomni_llm            = "claude-sonnet-4-5"
# certificate_arn       = "arn:aws:acm:us-east-1:123456789012:certificate/..."
