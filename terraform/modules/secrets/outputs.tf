output "anthropic_api_key_arn" {
  value = aws_secretsmanager_secret.anthropic_api_key.arn
}

output "openai_api_key_arn" {
  value = aws_secretsmanager_secret.openai_api_key.arn
}

output "tailscale_auth_key_arn" {
  value = aws_secretsmanager_secret.tailscale_auth_key.arn
}
