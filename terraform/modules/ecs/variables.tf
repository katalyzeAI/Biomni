variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "aws_region" {
  type = string
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "ecs_security_group_id" {
  type = string
}

variable "ecr_repository_url" {
  type = string
}

variable "container_image_tag" {
  type = string
}

variable "task_cpu" {
  type = number
}

variable "task_memory" {
  type = number
}

variable "ephemeral_storage_gib" {
  type = number
}

variable "desired_count" {
  type = number
}

variable "gradio_target_group_arn" {
  type = string
}

variable "api_target_group_arn" {
  type = string
}

variable "health_check_grace_period" {
  type = number
}

# EBS data lake
variable "data_lake_snapshot_id" {
  type = string
}

variable "data_lake_size_gib" {
  type = number
}

# Agent config
variable "biomni_llm" {
  type = string
}

variable "biomni_timeout_seconds" {
  type = number
}

# Secrets
variable "anthropic_api_key_arn" {
  type = string
}

variable "openai_api_key_arn" {
  type = string
}
