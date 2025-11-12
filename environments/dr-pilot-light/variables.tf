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

variable "primary_aws_region" {
  description = "AWS region of the primary deployment"
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

variable "cache_subnet_cidrs" {
  description = "CIDR blocks for ElastiCache subnets"
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

# ElastiCache variables
variable "enable_elasticache" {
  description = "Enable ElastiCache deployment"
  type        = bool
}

variable "cache_node_type" {
  description = "ElastiCache node type"
  type        = string
}

variable "cache_nodes" {
  description = "Number of Redis cache nodes"
  type        = number
}

variable "cache_security_group" {
  description = "Existing ElastiCache security group ID (when deploy_network = false)"
  type        = string
}

# DR Failover Variables
variable "domain_name" {
  description = "Domain name for the application"
  type        = string
}

variable "primary_alb_dns_name" {
  description = "DNS name of the primary region ALB"
  type        = string
}

variable "primary_alb_zone_id" {
  description = "Route 53 zone ID for the primary ALB"
  type        = string
}

variable "route53_hosted_zone_id" {
  description = "ID of an existing Route53 hosted zone"
  type        = string
  default     = ""
}

variable "create_route53_zone" {
  description = "Whether to create a new Route53 hosted zone"
  type        = bool
  default     = false
}

variable "health_check_path" {
  description = "Path for health check"
  type        = string
  default     = "/health"
}

variable "health_check_matcher" {
  description = "Response code matcher for health check"
  type        = string
  default     = "200-299"
}

variable "primary_db_instance_id" {
  description = "ID of the database instance in the primary region"
  type        = string
}

# Pilot Light Configuration
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

# Failover Configuration
variable "failover_min_capacity" {
  description = "Minimum capacity for DR environment during failover"
  type        = number
  default     = 3
}

variable "failover_max_capacity" {
  description = "Maximum capacity for DR environment during failover"
  type        = number
  default     = 10
}

variable "failover_desired_capacity" {
  description = "Desired capacity for DR environment during failover"
  type        = number
  default     = 3
}

# ECS Configuration
variable "ecs_instance_types" {
  description = "List of EC2 instance types for ECS"
  type        = list(string)
  default     = ["t3.medium", "t3a.medium"]
}

variable "ssh_key_name" {
  description = "SSH key name for EC2 instances"
  type        = string
  default     = ""
}

variable "use_spot_instances" {
  description = "Whether to use spot instances for ECS"
  type        = bool
  default     = true
}

variable "container_name" {
  description = "Name of the container"
  type        = string
  default     = "app"
}

variable "container_port" {
  description = "Port exposed by the container"
  type        = number
  default     = 80
}

variable "container_image" {
  description = "Docker image for the container"
  type        = string
}

variable "container_cpu" {
  description = "CPU units for the container"
  type        = number
  default     = 256
}

variable "container_memory" {
  description = "Memory for the container in MiB"
  type        = number
  default     = 512
}