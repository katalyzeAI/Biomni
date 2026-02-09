resource "aws_secretsmanager_secret" "anthropic_api_key" {
  name                    = "${var.project_name}/anthropic-api-key"
  description             = "Anthropic API key for Biomni agent"
  recovery_window_in_days = 7

  tags = { Name = "${var.project_name}-anthropic-key" }
}

resource "aws_secretsmanager_secret_version" "anthropic_api_key" {
  secret_id     = aws_secretsmanager_secret.anthropic_api_key.id
  secret_string = var.anthropic_api_key != "" ? var.anthropic_api_key : "REPLACE_ME"

  # Once set, manage the secret value via AWS console/CLI — not Terraform
  lifecycle { ignore_changes = [secret_string] }
}

resource "aws_secretsmanager_secret" "tailscale_auth_key" {
  name                    = "${var.project_name}/tailscale-auth-key"
  description             = "Tailscale auth key for VPN subnet router"
  recovery_window_in_days = 7

  tags = { Name = "${var.project_name}-tailscale-key" }
}

resource "aws_secretsmanager_secret_version" "tailscale_auth_key" {
  secret_id     = aws_secretsmanager_secret.tailscale_auth_key.id
  secret_string = var.tailscale_auth_key != "" ? var.tailscale_auth_key : "REPLACE_ME"

  lifecycle { ignore_changes = [secret_string] }
}

resource "aws_secretsmanager_secret" "openai_api_key" {
  name                    = "${var.project_name}/openai-api-key"
  description             = "OpenAI API key for Biomni agent"
  recovery_window_in_days = 7

  tags = { Name = "${var.project_name}-openai-key" }
}

resource "aws_secretsmanager_secret_version" "openai_api_key" {
  secret_id     = aws_secretsmanager_secret.openai_api_key.id
  secret_string = var.openai_api_key != "" ? var.openai_api_key : "REPLACE_ME"

  lifecycle { ignore_changes = [secret_string] }
}
