# Project variables
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

# Network variables
variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets"
  type        = list(string)
}

variable "database_subnet_cidrs" {
  description = "CIDR blocks for database subnets"
  type        = list(string)
}

variable "availability_zones" {
  description = "List of availability zones"
  type        = list(string)
}

variable "allowed_ssh_cidr" {
  description = "CIDR block allowed for SSH access"
  type        = string
}

# Database variables
variable "db_instance_class" {
  description = "Database instance class"
  type        = string
}

variable "db_allocated_storage" {
  description = "Allocated storage for database in GB"
  type        = number
}

variable "db_max_allocated_storage" {
  description = "Maximum allocated storage for database in GB"
  type        = number
}

variable "db_engine" {
  description = "Database engine (postgres or mysql)"
  type        = string
}

variable "db_engine_version" {
  description = "Database engine version"
  type        = string
}

variable "db_name" {
  description = "Name of the database"
  type        = string
}

variable "db_username" {
  description = "Username for the database"
  type        = string
}

variable "db_password" {
  description = "Password for the database (leave empty to generate random)"
  type        = string
  sensitive   = true
}

variable "db_port" {
  description = "Port for the database"
  type        = number
}

variable "db_multi_az" {
  description = "Enable multi-AZ for database"
  type        = bool
}

variable "enable_performance_insights" {
  description = "Enable Performance Insights"
  type        = bool
}

# Database parameters
variable "postgres_parameters" {
  description = "List of PostgreSQL parameters"
  type = list(object({
    name  = string
    value = string
  }))
}

variable "mysql_parameters" {
  description = "List of MySQL parameters"
  type = list(object({
    name  = string
    value = string
  }))
}

# Security variables
variable "waf_rate_limit" {
  description = "Rate limit for IP-based throttling (requests/5min)"
  type        = number
}

variable "waf_blocked_countries" {
  description = "List of country codes to block (ISO 3166-1 alpha-2 codes)"
  type        = list(string)
}

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

# Variables for pre-existing resources (when not creating new ones)
variable "vpc_id" {
  description = "Existing VPC ID (when deploy_network = false)"
  type        = string
  default     = ""
}

variable "private_subnets" {
  description = "Existing private subnet IDs (when deploy_network = false)"
  type        = list(string)
  default     = []
}

variable "public_subnets" {
  description = "Existing public subnet IDs (when deploy_network = false)"
  type        = list(string)
  default     = []
}

variable "database_subnets" {
  description = "Existing database subnet IDs (when deploy_network = false)"
  type        = list(string)
  default     = []
}

variable "db_security_group" {
  description = "Existing database security group ID (when deploy_network = false)"
  type        = string
  default     = ""
}