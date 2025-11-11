# IAM Module - Main Configuration

# ECS Task Execution Role
resource "aws_iam_role" "ecs_task_execution_role" {
  name = "${var.project}-${var.environment}-ecs-task-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "${var.project}-${var.environment}-ecs-task-execution-role"
    Environment = var.environment
    Project     = var.project
    Terraform   = "true"
  }
}

# Attach the AWS managed policy for ECS task execution
resource "aws_iam_role_policy_attachment" "ecs_task_execution_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# ECS Task Role
resource "aws_iam_role" "ecs_task_role" {
  name = "${var.project}-${var.environment}-ecs-task-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "${var.project}-${var.environment}-ecs-task-role"
    Environment = var.environment
    Project     = var.project
    Terraform   = "true"
  }
}

# Allow ECS tasks to access Secrets Manager
resource "aws_iam_policy" "secrets_manager_access" {
  name        = "${var.project}-${var.environment}-secrets-manager-access"
  description = "Allow access to Secrets Manager"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "secretsmanager:GetSecretValue",
          "kms:Decrypt"
        ]
        Effect   = "Allow"
        Resource = "arn:aws:secretsmanager:${var.aws_region}:${data.aws_caller_identity.current.account_id}:secret:/${var.project}/${var.environment}/*"
      }
    ]
  })
}

# Attach the Secrets Manager policy to the task role
resource "aws_iam_role_policy_attachment" "ecs_task_secrets_manager" {
  role       = aws_iam_role.ecs_task_role.name
  policy_arn = aws_iam_policy.secrets_manager_access.arn
}

# Jenkins Role
resource "aws_iam_role" "jenkins_role" {
  name = "${var.project}-${var.environment}-jenkins-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "${var.project}-${var.environment}-jenkins-role"
    Environment = var.environment
    Project     = var.project
    Terraform   = "true"
  }
}

# Jenkins Instance Profile
resource "aws_iam_instance_profile" "jenkins" {
  name = "${var.project}-${var.environment}-jenkins-profile"
  role = aws_iam_role.jenkins_role.name
}

# Jenkins Policy for ECR and ECS Access
resource "aws_iam_policy" "jenkins_ecr_ecs_access" {
  name        = "${var.project}-${var.environment}-jenkins-ecr-ecs-access"
  description = "Allow Jenkins to push to ECR and deploy to ECS"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
          "ecr:PutImage"
        ]
        Effect   = "Allow"
        Resource = "*"
      },
      {
        Action = [
          "ecs:DescribeServices",
          "ecs:UpdateService",
          "ecs:RegisterTaskDefinition",
          "ecs:DescribeTaskDefinition",
          "ecs:ListTaskDefinitions",
          "ecs:DeregisterTaskDefinition"
        ]
        Effect   = "Allow"
        Resource = "*"
      }
    ]
  })
}

# Attach policies to Jenkins role
resource "aws_iam_role_policy_attachment" "jenkins_ecr_ecs" {
  role       = aws_iam_role.jenkins_role.name
  policy_arn = aws_iam_policy.jenkins_ecr_ecs_access.arn
}

# CodeDeploy Role
resource "aws_iam_role" "codedeploy_role" {
  name = "${var.project}-${var.environment}-codedeploy-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "codedeploy.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "${var.project}-${var.environment}-codedeploy-role"
    Environment = var.environment
    Project     = var.project
    Terraform   = "true"
  }
}

# Attach AWS managed policy for CodeDeploy
resource "aws_iam_role_policy_attachment" "codedeploy" {
  role       = aws_iam_role.codedeploy_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSCodeDeployRole"
}

# Get current AWS account ID
data "aws_caller_identity" "current" {}