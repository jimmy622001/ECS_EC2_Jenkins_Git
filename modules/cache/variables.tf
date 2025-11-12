variable "project" {
  description = "Project name"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "private_subnets" {
  description = "List of private subnet IDs"
  type        = list(string)
}

variable "cache_security_group" {
  description = "Security group ID for ElastiCache"
  type        = string
}

variable "cache_node_type" {
  description = "Node type for ElastiCache cluster"
  type        = string
  default     = "cache.t3.micro" # For dev - use cache.m5.large or higher for production
}

variable "cache_nodes" {
  description = "Number of cache nodes"
  type        = number
  default     = 1 # Consider increasing for production
}