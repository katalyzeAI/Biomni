variable "aws_region" {
  description = "AWS region for all resources"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Deployment environment (e.g. prod, staging)"
  type        = string
  default     = "prod"
}

variable "project_name" {
  description = "Project name used for resource naming"
  type        = string
  default     = "biomni"
}

# --- Networking ---

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "Availability zones for subnets"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

# --- ECS ---

variable "task_cpu" {
  description = "Fargate task CPU units (1024 = 1 vCPU)"
  type        = number
  default     = 8192
}

variable "task_memory" {
  description = "Fargate task memory in MiB"
  type        = number
  default     = 32768
}

variable "ephemeral_storage_gib" {
  description = "Ephemeral storage for the Fargate task in GiB"
  type        = number
  default     = 40
}

variable "desired_count" {
  description = "Number of ECS tasks to run"
  type        = number
  default     = 1
}

variable "container_image_tag" {
  description = "Docker image tag to deploy"
  type        = string
  default     = "e1"
}

# --- EBS Data Lake ---

variable "data_lake_snapshot_id" {
  description = "EBS snapshot ID containing the pre-populated data lake"
  type        = string
}

variable "data_lake_size_gib" {
  description = "Size of the EBS data lake volume in GiB"
  type        = number
  default     = 15
}

# --- ALB / TLS ---

variable "certificate_arn" {
  description = "ACM certificate ARN for HTTPS. Leave empty to use HTTP only."
  type        = string
  default     = ""
}

variable "health_check_grace_period" {
  description = "Seconds to wait before ALB health checks start (cold-start buffer)"
  type        = number
  default     = 300
}

# --- Agent Config ---

variable "biomni_llm" {
  description = "LLM model name for the Biomni agent"
  type        = string
  default     = "claude-sonnet-4-5"
}

variable "biomni_timeout_seconds" {
  description = "Timeout for agent code execution in seconds"
  type        = number
  default     = 600
}

# --- Secrets ---

variable "anthropic_api_key" {
  description = "Anthropic API key (stored in Secrets Manager)"
  type        = string
  sensitive   = true
}

variable "openai_api_key" {
  description = "OpenAI API key (stored in Secrets Manager)"
  type        = string
  sensitive   = true
  default     = ""
}
