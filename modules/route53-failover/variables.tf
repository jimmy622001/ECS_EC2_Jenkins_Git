variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
}

variable "domain_name" {
  description = "Domain name for the application"
  type        = string
}

variable "primary_endpoint" {
  description = "DNS name of the primary region endpoint (ALB/NLB)"
  type        = string
}

variable "primary_zone_id" {
  description = "Route 53 zone ID for the primary endpoint's alias record"
  type        = string
}

variable "secondary_endpoint" {
  description = "DNS name of the secondary (DR) region endpoint (ALB/NLB)"
  type        = string
}

variable "secondary_zone_id" {
  description = "Route 53 zone ID for the secondary endpoint's alias record"
  type        = string
}

variable "create_zone" {
  description = "Whether to create a new Route53 hosted zone or use existing one"
  type        = bool
  default     = false
}

variable "hosted_zone_id" {
  description = "ID of an existing Route53 hosted zone if not creating a new one"
  type        = string
  default     = ""
}

variable "health_check_path" {
  description = "Path to check for the health check"
  type        = string
  default     = "/health"
}

variable "lambda_arn" {
  description = "ARN of the Lambda function to invoke on failover"
  type        = string
  default     = ""
}

variable "lambda_name" {
  description = "Name of the Lambda function to invoke on failover"
  type        = string
  default     = ""
}

variable "create_lambda_integration" {
  description = "Whether to create SNS subscription and Lambda permissions"
  type        = bool
  default     = false
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}