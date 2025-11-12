# Configure cross-region replication for RDS
# This file is conditionally used when enable_replication = true

# Create a read replica in DR region when this is deployed in the primary region
resource "aws_db_instance" "read_replica" {
  count = var.enable_replication && var.is_primary ? 1 : 0
  
  # Not all attributes can be specified when creating a replica
  identifier             = "${var.project}-${var.environment}-dr-replica"
  replicate_source_db    = aws_db_instance.main.identifier
  instance_class         = var.db_instance_class
  vpc_security_group_ids = [var.db_security_group]
  availability_zone      = length(var.availability_zones) > 0 ? var.availability_zones[0] : null
  multi_az               = false # Usually single-AZ for cost savings in pilot light
  
  # Keep automatic backups disabled for replica to reduce costs
  backup_retention_period = 0
  skip_final_snapshot     = true
  
  # Configure doctor provider for the DR region
  provider = aws.dr_region
  
  tags = {
    Name        = "${var.project}-${var.environment}-dr-replica"
    Project     = var.project
    Environment = var.environment
    Managed_by  = "terraform"
    DR          = "true"
  }
}

# Create a read replica from the primary region when this is deployed in the DR region
resource "aws_db_instance" "primary_replica" {
  count = var.enable_replication && !var.is_primary ? 1 : 0
  
  identifier             = "${var.project}-${var.environment}-replica"
  replicate_source_db    = var.primary_db_instance_id
  instance_class         = var.db_instance_class
  vpc_security_group_ids = [var.db_security_group]
  availability_zone      = length(var.availability_zones) > 0 ? var.availability_zones[0] : null
  multi_az               = false
  
  backup_retention_period = 0
  skip_final_snapshot     = true
  
  tags = {
    Name        = "${var.project}-${var.environment}-replica"
    Project     = var.project
    Environment = var.environment
    Managed_by  = "terraform"
    DR          = "true"
  }
}