# Disaster Recovery Environment Configuration
# Updated with automatic failover, scaling capabilities and monthly testing

# Provider for the DR region
provider "aws" {
  alias  = "dr_region"
  region = var.aws_region
}

# Provider for the primary region
provider "aws" {
  alias  = "primary_region"
  region = var.primary_aws_region
}

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

# ElastiCache Module - conditionally deployed
module "cache" {
  count  = var.enable_elasticache ? 1 : 0
  source = "../../modules/cache"

  project     = var.project
  environment = var.environment

  cache_subnets       = module.network.cache_subnets
  cache_security_group = module.network.cache_security_group

  cache_node_type     = var.cache_node_type
  cache_nodes         = var.cache_nodes
}

# ECS Module - deployed in pilot light mode initially
module "ecs" {
  source = "../../modules/ecs"
  providers = {
    aws = aws.dr_region
  }

  project     = var.project
  environment = var.environment
  aws_region  = var.aws_region

  vpc_id              = module.network.vpc_id
  private_subnets     = module.network.private_subnets
  public_subnets      = module.network.public_subnets
  ecs_security_group  = module.network.ecs_security_group
  alb_security_group  = module.network.alb_security_group

  # IAM roles
  ecs_task_execution_role = module.iam.ecs_task_execution_role
  ecs_task_role = module.iam.ecs_task_role

  # EC2 instance configuration
  container_insights = true
  instance_type = var.ecs_instance_types[0]
  ssh_key_name = var.ssh_key_name

  # Pilot light configuration
  min_capacity     = var.pilot_min_capacity
  max_capacity     = var.pilot_max_capacity

  # Task configuration
  task_cpu = var.container_cpu
  task_memory = var.container_memory
  container_port = var.container_port
  container_image = var.container_image
  health_check_path = var.health_check_path
  desired_task_count = 1

  # SSL configuration
  domain_name = var.domain_name
  create_dummy_cert = true
  acm_certificate_arn = ""
}

# DR Lambda module for automated scaling during failover
module "dr_lambda" {
  source = "../../modules/dr-lambda"
  providers = {
    aws = aws.dr_region
  }

  name_prefix        = "${var.project}-${var.environment}"
  primary_region     = var.primary_aws_region
  dr_region          = var.aws_region
  ecs_cluster_name   = module.ecs.cluster_name
  ecs_service_name   = module.ecs.service_name
  asg_name           = module.ecs.asg_name

  # Failover configuration
  min_capacity       = var.failover_min_capacity
  max_capacity       = var.failover_max_capacity
  desired_capacity   = var.failover_desired_capacity
  
  # Pilot light configuration
  pilot_min_capacity     = var.pilot_min_capacity
  pilot_max_capacity     = var.pilot_max_capacity
  pilot_desired_capacity = var.pilot_desired_capacity
  
  # We need to hardcode an empty string here instead of using a computed value
  # that depends on a conditional. This will be updated after the first apply.
  route53_health_check_id = ""
  
  tags = {
    Project     = var.project
    Environment = var.environment
  }
}

# Route53 failover configuration
module "route53_failover" {
  source = "../../modules/route53-failover"
  providers = {
    aws = aws.primary_region
  }

  name_prefix        = "${var.project}-${var.environment}"
  domain_name        = var.domain_name
  primary_endpoint   = var.primary_alb_dns_name
  primary_zone_id    = var.primary_alb_zone_id
  secondary_endpoint = module.ecs.alb_dns_name
  secondary_zone_id  = module.ecs.alb_zone_id
  hosted_zone_id     = var.route53_hosted_zone_id
  create_zone        = var.create_route53_zone
  health_check_path  = var.health_check_path
  lambda_arn         = module.dr_lambda.lambda_arn
  lambda_name        = module.dr_lambda.lambda_name
  create_lambda_integration = true

  tags = {
    Project     = var.project
    Environment = var.environment
  }
}