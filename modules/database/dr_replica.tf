# DR Read Replica configuration
# This creates a read replica in DR region for disaster recovery purposes

resource "aws_db_instance" "dr_replica" {
  count = var.create_dr_read_replica && var.environment == "prod" ? 1 : 0
  
  identifier             = "${var.project}-${var.environment}-dr-read-replica"
  replicate_source_db    = aws_db_instance.main.identifier
  instance_class         = var.dr_replica_instance_class
  vpc_security_group_ids = [var.db_security_group]
  availability_zone      = length(var.availability_zones) > 0 ? var.availability_zones[0] : null
  multi_az               = false
  
  backup_retention_period = var.replica_backup_retention_period
  skip_final_snapshot     = false
  final_snapshot_identifier = "${var.project}-${var.environment}-dr-replica-final-${formatdate("YYYYMMDDhhmmss", timestamp())}"
  
  provider = aws.dr_region
  
  tags = {
    Name        = "${var.project}-${var.environment}-dr-read-replica"
    Project     = var.project
    Environment = var.environment
    Managed_by  = "terraform"
    DR          = "true"
  }
}

# SNS Topic for replication failures
resource "aws_sns_topic" "replication_failures" {
  count = var.replication_sns_topic_arn == "" && (var.enable_cross_region_replica || var.create_dr_read_replica) && var.environment == "prod" ? 1 : 0
  
  name = "${var.project}-${var.environment}-replication-failures"
  
  tags = {
    Name        = "${var.project}-${var.environment}-replication-failures"
    Project     = var.project
    Environment = var.environment
    Managed_by  = "terraform"
  }
}

# Send replication failure notifications to the SNS topic
resource "aws_db_event_subscription" "replication_failures" {
  count = var.replication_sns_topic_arn == "" && (var.enable_cross_region_replica || var.create_dr_read_replica) && var.environment == "prod" ? 1 : 0
  
  name      = "${var.project}-${var.environment}-replication-failures"
  sns_topic = aws_sns_topic.replication_failures[0].arn
  
  source_type = "db-instance"
  source_ids  = var.create_dr_read_replica ? [aws_db_instance.dr_replica[0].id] : []
  
  event_categories = [
    "availability",
    "deletion",
    "failover",
    "failure",
    "low storage",
    "maintenance",
    "notification",
    "recovery"
  ]
  
  tags = {
    Name        = "${var.project}-${var.environment}-replication-failures"
    Project     = var.project
    Environment = var.environment
    Managed_by  = "terraform"
  }
}