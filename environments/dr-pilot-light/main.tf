# Disaster Recovery Environment Configuration

# Network Module
module "network" {
  source = "../../modules/network"

  project               = var.project
  environment           = var.environment
  aws_region            = var.aws_region
  vpc_cidr              = var.vpc_cidr
  public_subnet_cidrs   = var.public_subnet_cidrs
  private_subnet_cidrs  = var.private_subnet_cidrs
  database_subnet_cidrs = var.database_subnet_cidrs
  cache_subnet_cidrs    = var.cache_subnet_cidrs
  availability_zones    = var.availability_zones
  allowed_ssh_cidr      = var.allowed_ssh_cidr
}

# IAM Module
module "iam" {
  source = "../../modules/iam"

  project     = var.project
  environment = var.environment
  aws_region  = var.aws_region
}

# Security Module - Minimal Setup for DR
module "security" {
  source = "../../modules/security"

  project     = var.project
  environment = var.environment
  aws_region  = var.aws_region

  vpc_id  = module.network.vpc_id
  alb_arn = "" # No ALB in Pilot Light mode

  rate_limit             = var.waf_rate_limit
  blocked_countries      = var.waf_blocked_countries
  enable_security_hub    = var.enable_security_hub
  enable_guardduty       = var.enable_guardduty
  enable_config          = var.enable_config
  enable_waf_association = false
}

# Database Module - Set up as a replica
module "database" {
  source = "../../modules/database"

  project     = var.project
  environment = var.environment
  aws_region  = var.aws_region

  vpc_id            = module.network.vpc_id
  database_subnets  = module.network.database_subnets
  db_security_group = module.network.db_security_group

  db_engine                   = var.db_engine
  db_engine_version           = var.db_engine_version
  db_instance_class           = var.db_instance_class
  db_allocated_storage        = var.db_allocated_storage
  db_max_allocated_storage    = var.db_max_allocated_storage
  db_name                     = var.db_name
  db_username                 = var.db_username
  db_password                 = var.db_password
  db_port                     = var.db_port
  db_multi_az                 = var.db_multi_az
  enable_performance_insights = var.enable_performance_insights
  postgres_parameters         = var.postgres_parameters
  mysql_parameters            = var.mysql_parameters
}

# ElastiCache Module
module "cache" {
  source = "../../modules/cache"

  project     = var.project
  environment = var.environment

  cache_subnets       = module.network.cache_subnets
  cache_security_group = module.network.cache_security_group

  cache_node_type     = var.cache_node_type
  cache_nodes         = var.cache_nodes
}