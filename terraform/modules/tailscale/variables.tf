variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "vpc_cidr" {
  type = string
}

variable "aws_region" {
  type = string
}

variable "subnet_id" {
  description = "Public subnet for the Tailscale router (needs internet access)"
  type        = string
}

variable "tailscale_auth_key_arn" {
  description = "Secrets Manager ARN for the Tailscale auth key"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type for the subnet router"
  type        = string
  default     = "t3.micro"
}
