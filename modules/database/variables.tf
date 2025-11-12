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

# Cross-region replication variables
variable "enable_cross_region_replica" {
  description = "Enable cross-region automated backup replication"
  type        = bool
  default     = false
}

variable "create_dr_read_replica" {
  description = "Create a read replica in the DR region"
  type        = bool
  default     = false
}

variable "dr_replica_instance_class" {
  description = "Instance class for DR read replica"
  type        = string
  default     = "db.t3.medium"
}

variable "replica_backup_retention_period" {
  description = "Number of days to retain automated backups for the replica"
  type        = number
  default     = 7
}

variable "replica_kms_key_id" {
  description = "The ARN for the KMS encryption key for replica backups"
  type        = string
  default     = null
}

variable "replication_sns_topic_arn" {
  description = "ARN of SNS topic for replication event notifications"
  type        = string
  default     = ""
}

variable "dr_region" {
  description = "AWS region for DR environment"
  type        = string
  default     = "eu-west-1"
}

variable "enable_replication" {
  description = "Enable database replication"
  type        = bool
  default     = false
}

variable "is_primary" {
  description = "Whether this is the primary DB instance for replication"
  type        = bool
  default     = true
}

variable "primary_db_instance_id" {
  description = "ID of the primary DB instance for replication"
  type        = string
  default     = ""
}

variable "availability_zones" {
  description = "List of availability zones"
  type        = list(string)
  default     = []
}

# Network variables
variable "vpc_id" {
  description = "ID of the VPC"
  type        = string
}

variable "database_subnets" {
  description = "IDs of the database subnets"
  type        = list(string)
}

variable "db_security_group" {
  description = "ID of the database security group"
  type        = string
}

# Database configuration
variable "db_engine" {
  description = "Database engine (postgres or mysql)"
  type        = string
}

variable "db_engine_version" {
  description = "Database engine version"
  type        = string
}

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

# PostgreSQL specific parameters
variable "postgres_parameters" {
  description = "List of PostgreSQL parameters"
  type = list(object({
    name  = string
    value = string
  }))
}

# MySQL specific parameters
variable "mysql_parameters" {
  description = "List of MySQL parameters"
  type = list(object({
    name  = string
    value = string
  }))
}