# Database Module - Main Configuration

# RDS DB Subnet Group
resource "aws_db_subnet_group" "main" {
  name        = "${var.project}-${var.environment}-subnet-group"
  description = "DB subnet group for ${var.project}-${var.environment}"
  subnet_ids  = var.database_subnets

  tags = {
    Name        = "${var.project}-${var.environment}-subnet-group"
    Environment = var.environment
    Project     = var.project
    Terraform   = "true"
  }
}

# Random password for database if not provided
resource "random_password" "db_password" {
  count            = var.db_password == "" ? 1 : 0
  length           = 16
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

# RDS PostgreSQL Instance
resource "aws_db_instance" "main" {
  identifier             = "${var.project}-${var.environment}-db"
  engine                 = var.db_engine
  engine_version         = var.db_engine_version
  instance_class         = var.db_instance_class
  allocated_storage      = var.db_allocated_storage
  max_allocated_storage  = var.db_max_allocated_storage
  storage_type           = "gp3"
  storage_encrypted      = true
  db_name                = var.db_name
  username               = var.db_username
  password               = var.db_password == "" ? random_password.db_password[0].result : var.db_password
  port                   = var.db_port
  vpc_security_group_ids = [var.db_security_group]
  db_subnet_group_name   = aws_db_subnet_group.main.name
  parameter_group_name   = aws_db_parameter_group.main.name
  option_group_name      = var.db_engine == "mysql" ? aws_db_option_group.mysql[0].name : null

  publicly_accessible    = false
  skip_final_snapshot    = var.environment == "prod" ? false : true
  copy_tags_to_snapshot  = true
  backup_retention_period = var.environment == "prod" ? 30 : 7
  backup_window          = "03:00-04:00"
  maintenance_window     = "sun:04:30-sun:05:30"
  multi_az               = var.db_multi_az
  deletion_protection    = var.environment == "prod" ? true : false
  
  performance_insights_enabled = var.enable_performance_insights
  monitoring_interval          = 60
  monitoring_role_arn          = aws_iam_role.rds_monitoring_role.arn
  enabled_cloudwatch_logs_exports = var.db_engine == "postgres" ? ["postgresql", "upgrade"] : ["audit", "error", "general", "slowquery"]
  
  apply_immediately      = var.environment == "prod" ? false : true
  auto_minor_version_upgrade = true

  lifecycle {
    ignore_changes = [password]
  }

  tags = {
    Name        = "${var.project}-${var.environment}-db"
    Environment = var.environment
    Project     = var.project
    Terraform   = "true"
  }
}

# Parameter group for PostgreSQL
resource "aws_db_parameter_group" "main" {
  name        = "${var.project}-${var.environment}-pg"
  family      = var.db_engine == "postgres" ? "postgres${replace(var.db_engine_version, ".", "")}" : "mysql${replace(var.db_engine_version, ".", "")}"
  description = "Parameter group for ${var.project}-${var.environment} ${var.db_engine}"

  dynamic "parameter" {
    for_each = var.db_engine == "postgres" ? var.postgres_parameters : var.mysql_parameters
    content {
      name  = parameter.value.name
      value = parameter.value.value
    }
  }

  tags = {
    Name        = "${var.project}-${var.environment}-pg"
    Environment = var.environment
    Project     = var.project
    Terraform   = "true"
  }
}

# Option group for MySQL (only created if using MySQL)
resource "aws_db_option_group" "mysql" {
  count = var.db_engine == "mysql" ? 1 : 0
  
  name                     = "${var.project}-${var.environment}-og"
  option_group_description = "Option group for ${var.project}-${var.environment} MySQL"
  engine_name              = "mysql"
  major_engine_version     = element(split(".", var.db_engine_version), 0)

  option {
    option_name = "MARIADB_AUDIT_PLUGIN"
    
    option_settings {
      name  = "SERVER_AUDIT_EVENTS"
      value = "CONNECT,QUERY"
    }
  }

  tags = {
    Name        = "${var.project}-${var.environment}-og"
    Environment = var.environment
    Project     = var.project
    Terraform   = "true"
  }
}

# IAM Role for RDS Enhanced Monitoring
resource "aws_iam_role" "rds_monitoring_role" {
  name = "${var.project}-${var.environment}-rds-monitoring-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "monitoring.rds.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "${var.project}-${var.environment}-rds-monitoring-role"
    Environment = var.environment
    Project     = var.project
    Terraform   = "true"
  }
}

# Attach RDS monitoring policy
resource "aws_iam_role_policy_attachment" "rds_monitoring" {
  role       = aws_iam_role.rds_monitoring_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

# Store database credentials in Secrets Manager
resource "aws_secretsmanager_secret" "db_credentials" {
  name        = "/${var.project}/${var.environment}/database"
  description = "Database credentials for ${var.project} ${var.environment}"
  
  tags = {
    Name        = "${var.project}-${var.environment}-db-credentials"
    Environment = var.environment
    Project     = var.project
    Terraform   = "true"
  }

  recovery_window_in_days = var.environment == "dev" ? 0 : 30
}

resource "aws_secretsmanager_secret_version" "db_credentials" {
  secret_id = aws_secretsmanager_secret.db_credentials.id

  secret_string = jsonencode({
    username = var.db_username
    password = var.db_password == "" ? random_password.db_password[0].result : var.db_password
    engine   = var.db_engine
    host     = aws_db_instance.main.address
    port     = aws_db_instance.main.port
    dbname   = var.db_name
    url      = "${var.db_engine}://${var.db_username}:${var.db_password == "" ? random_password.db_password[0].result : var.db_password}@${aws_db_instance.main.address}:${aws_db_instance.main.port}/${var.db_name}"
  })
}

# RDS Proxy Configuration
# Commented out to avoid extra costs during development
# Uncomment when preparing for production deployment or for connection pooling needs

/*
# IAM Role for RDS Proxy
resource "aws_iam_role" "proxy_role" {
  name = "${var.project}-${var.environment}-proxy-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "rds.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "${var.project}-${var.environment}-proxy-role"
    Environment = var.environment
    Project     = var.project
    Terraform   = "true"
  }
}

# IAM Policy for RDS Proxy to access Secrets Manager
resource "aws_iam_role_policy" "proxy_policy" {
  name = "${var.project}-${var.environment}-proxy-policy"
  role = aws_iam_role.proxy_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = [aws_secretsmanager_secret.db_credentials.arn]
      }
    ]
  })
}

# RDS Proxy
resource "aws_db_proxy" "main" {
  name                   = "${var.project}-${var.environment}-db-proxy"
  engine_family          = var.db_engine == "postgres" ? "POSTGRESQL" : "MYSQL"
  idle_client_timeout    = 1800
  require_tls            = true
  role_arn               = aws_iam_role.proxy_role.arn
  vpc_subnet_ids         = var.database_subnets
  vpc_security_group_ids = [var.db_security_group]

  auth {
    auth_scheme = "SECRETS"
    iam_auth    = "DISABLED"
    secret_arn  = aws_secretsmanager_secret.db_credentials.arn
  }

  tags = {
    Name        = "${var.project}-${var.environment}-db-proxy"
    Environment = var.environment
    Project     = var.project
    Terraform   = "true"
  }
}

# RDS Proxy Default Target Group
resource "aws_db_proxy_default_target_group" "main" {
  db_proxy_name = aws_db_proxy.main.name

  connection_pool_config {
    connection_borrow_timeout    = 120
    max_connections_percent      = 100
    max_idle_connections_percent = 50
    session_pinning_filters      = []
  }
}

# RDS Proxy Target
resource "aws_db_proxy_target" "main" {
  db_proxy_name          = aws_db_proxy.main.name
  target_group_name      = aws_db_proxy_default_target_group.main.name
  db_instance_identifier = aws_db_instance.main.id
}
*/