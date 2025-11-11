# CI/CD Module - Main Configuration

# Jenkins EC2 instance
resource "aws_instance" "jenkins" {
  ami                    = data.aws_ami.amazon_linux_2.id
  instance_type          = var.jenkins_instance_type
  subnet_id              = var.public_subnets[0]
  vpc_security_group_ids = [var.jenkins_security_group]
  iam_instance_profile   = var.jenkins_instance_profile
  key_name               = var.ssh_key_name

  root_block_device {
    volume_type           = "gp3"
    volume_size           = 30
    delete_on_termination = true
    encrypted             = true
  }

  user_data = <<-EOF
    #!/bin/bash
    # Install required packages
    amazon-linux-extras install epel -y
    yum update -y
    yum install -y wget git unzip

    # Install Java
    amazon-linux-extras install java-openjdk11 -y

    # Install Jenkins
    wget -O /etc/yum.repos.d/jenkins.repo https://pkg.jenkins.io/redhat-stable/jenkins.repo
    rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io.key
    yum install -y jenkins
    systemctl enable jenkins
    systemctl start jenkins

    # Install Docker
    amazon-linux-extras install docker -y
    systemctl enable docker
    systemctl start docker
    usermod -aG docker jenkins
    usermod -aG docker ec2-user

    # Install AWS CLI v2
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
    unzip awscliv2.zip
    ./aws/install

    # Install Terraform
    TERRAFORM_VERSION="1.4.6"
    wget https://releases.hashicorp.com/terraform/$${TERRAFORM_VERSION}/terraform_$${TERRAFORM_VERSION}_linux_amd64.zip
    unzip terraform_$${TERRAFORM_VERSION}_linux_amd64.zip
    mv terraform /usr/local/bin/

    # Restart Jenkins to apply changes
    systemctl restart jenkins
  EOF

  tags = {
    Name        = "${var.project}-${var.environment}-jenkins"
    Environment = var.environment
    Project     = var.project
    Terraform   = "true"
  }
}

# Elastic IP for Jenkins
resource "aws_eip" "jenkins" {
  domain = "vpc"
  instance = aws_instance.jenkins.id
  
  tags = {
    Name        = "${var.project}-${var.environment}-jenkins-eip"
    Environment = var.environment
    Project     = var.project
    Terraform   = "true"
  }
}

# ECR Repository
resource "aws_ecr_repository" "app" {
  name                 = "${var.project}-${var.environment}"
  image_tag_mutability = "IMMUTABLE"
  
  image_scanning_configuration {
    scan_on_push = true
  }
  
  encryption_configuration {
    encryption_type = "KMS"
  }
  
  tags = {
    Name        = "${var.project}-${var.environment}-ecr"
    Environment = var.environment
    Project     = var.project
    Terraform   = "true"
  }
}

# ECR Lifecycle Policy
resource "aws_ecr_lifecycle_policy" "app" {
  repository = aws_ecr_repository.app.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 30 images"
        selection = {
          tagStatus     = "any"
          countType     = "imageCountMoreThan"
          countNumber   = 30
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

# CodeDeploy Application
resource "aws_codedeploy_app" "app" {
  name = "${var.project}-${var.environment}-app"
  compute_platform = "ECS"
}

# CodeDeploy Deployment Group
resource "aws_codedeploy_deployment_group" "app" {
  app_name               = aws_codedeploy_app.app.name
  deployment_group_name  = var.codedeploy_group_name
  deployment_config_name = "CodeDeployDefault.ECSAllAtOnce"
  service_role_arn       = var.codedeploy_role

  auto_rollback_configuration {
    enabled = true
    events  = ["DEPLOYMENT_FAILURE"]
  }

  deployment_style {
    deployment_option = "WITH_TRAFFIC_CONTROL"
    deployment_type   = "BLUE_GREEN"
  }

  ecs_service {
    cluster_name = var.ecs_cluster_name
    service_name = var.ecs_service_name
  }

  load_balancer_info {
    target_group_pair_info {
      prod_traffic_route {
        listener_arns = [var.alb_listener_arn]
      }

      target_group {
        name = var.alb_target_group_name_blue
      }

      target_group {
        name = var.alb_target_group_name_green
      }
    }
  }

  blue_green_deployment_config {
    deployment_ready_option {
      action_on_timeout = "CONTINUE_DEPLOYMENT"
    }

    terminate_blue_instances_on_deployment_success {
      action                           = "TERMINATE"
      termination_wait_time_in_minutes = 5
    }
  }

  tags = {
    Name        = "${var.project}-${var.environment}-deployment-group"
    Environment = var.environment
    Project     = var.project
    Terraform   = "true"
  }
}

# Get the latest Amazon Linux 2 AMI
data "aws_ami" "amazon_linux_2" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Outputs
output "jenkins_instance_id" {
  description = "ID of the Jenkins EC2 instance"
  value       = aws_instance.jenkins.id
}

output "jenkins_public_ip" {
  description = "Public IP of the Jenkins EC2 instance"
  value       = aws_eip.jenkins.public_ip
}

output "ecr_repository_url" {
  description = "URL of the ECR repository"
  value       = aws_ecr_repository.app.repository_url
}

output "codedeploy_app_name" {
  description = "Name of the CodeDeploy application"
  value       = aws_codedeploy_app.app.name
}

output "codedeploy_deployment_group_name" {
  description = "Name of the CodeDeploy deployment group"
  value       = aws_codedeploy_deployment_group.app.deployment_group_name
}