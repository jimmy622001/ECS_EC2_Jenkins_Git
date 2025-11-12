variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
}

variable "primary_region" {
  description = "AWS region for primary environment"
  type        = string
}

variable "dr_region" {
  description = "AWS region for DR environment"
  type        = string
}

variable "ecs_cluster_name" {
  description = "Name of the ECS cluster in DR region"
  type        = string
}

variable "ecs_service_name" {
  description = "Name of the ECS service in DR region"
  type        = string
}

variable "asg_name" {
  description = "Name of the AutoScaling Group for ECS in DR region"
  type        = string
}

variable "min_capacity" {
  description = "Minimum capacity for DR environment during failover"
  type        = number
  default     = 3
}

variable "max_capacity" {
  description = "Maximum capacity for DR environment during failover"
  type        = number
  default     = 10
}

variable "desired_capacity" {
  description = "Desired capacity for DR environment during failover"
  type        = number
  default     = 3
}

variable "pilot_min_capacity" {
  description = "Minimum capacity for pilot light environment"
  type        = number
  default     = 1
}

variable "pilot_max_capacity" {
  description = "Maximum capacity for pilot light environment"
  type        = number
  default     = 2
}

variable "pilot_desired_capacity" {
  description = "Desired capacity for pilot light environment"
  type        = number
  default     = 1
}

variable "route53_health_check_id" {
  description = "ID of the Route 53 health check that monitors the primary region"
  type        = string
  default     = ""
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}