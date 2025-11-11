variable "project" {
  description = "Project name"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "vpc_id" {
  description = "ID of the VPC"
  type        = string
}

variable "alb_arn" {
  description = "ARN of the Application Load Balancer"
  type        = string
}

# WAF variables
variable "rate_limit" {
  description = "Rate limit for IP-based throttling (requests/5min)"
  type        = number
}

variable "blocked_countries" {
  description = "List of country codes to block (ISO 3166-1 alpha-2 codes)"
  type        = list(string)
}

# Security service enablement
variable "enable_security_hub" {
  description = "Enable AWS Security Hub"
  type        = bool
}

variable "enable_guardduty" {
  description = "Enable AWS GuardDuty"
  type        = bool
}

variable "enable_config" {
  description = "Enable AWS Config"
  type        = bool
}

variable "enable_waf_association" {
  description = "Enable WAF association with ALB"
  type        = bool
}