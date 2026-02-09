variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "subnet_ids" {
  description = "Subnets for the ALB (private when internal, public when internet-facing)"
  type        = list(string)
}

variable "internal" {
  description = "Whether the ALB is internal (true) or internet-facing (false)"
  type        = bool
  default     = true
}

variable "alb_security_group_id" {
  type = string
}

variable "certificate_arn" {
  type    = string
  default = ""
}
