# ElastiCache module for Redis caching

resource "aws_elasticache_subnet_group" "main" {
  name       = "${var.project}-${var.environment}-cache-subnet-group"
  subnet_ids = var.cache_subnets
}

# Use a replication group instead of a cluster for multi-AZ support
resource "aws_elasticache_replication_group" "redis" {
  replication_group_id       = "${var.project}-${var.environment}-redis"
  description               = "${var.project}-${var.environment} Redis replication group"
  node_type                 = var.cache_node_type
  num_cache_clusters        = var.cache_nodes
  parameter_group_name      = "default.redis6.x"
  engine_version            = "6.2"
  port                      = 6379
  subnet_group_name         = aws_elasticache_subnet_group.main.name
  security_group_ids        = [var.cache_security_group]
  automatic_failover_enabled = var.cache_nodes > 1 ? true : false
  multi_az_enabled          = var.cache_nodes > 1 ? true : false

  tags = {
    Name        = "${var.project}-${var.environment}-redis"
    Environment = var.environment
    Project     = var.project
    Terraform   = "true"
  }
}

output "redis_endpoint" {
  description = "Redis primary endpoint"
  value       = aws_elasticache_replication_group.redis.primary_endpoint_address
}

output "redis_reader_endpoint" {
  description = "Redis reader endpoint"
  value       = aws_elasticache_replication_group.redis.reader_endpoint_address
}

output "redis_port" {
  description = "Redis port"
  value       = aws_elasticache_replication_group.redis.port
}