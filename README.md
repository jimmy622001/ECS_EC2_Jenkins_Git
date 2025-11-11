# ECS EC2 Jenkins GitHub Integration

This project provides a complete AWS infrastructure deployment for containerized applications using:

- **Amazon ECS** on EC2 for container orchestration
- **Jenkins** for CI/CD pipeline
- **GitHub** integration for source control
- **Multiple environment support** (dev, prod, disaster recovery)

## Architecture Overview

![Architecture Diagram](docs/architecture.png)

The infrastructure is divided into the following modules:

1. **Network**: VPC, subnets, security groups, and networking components
2. **IAM**: Roles and policies for ECS, Jenkins, and other services
3. **ECS**: Container orchestration, load balancer, and auto-scaling
4. **Database**: RDS instances for application data
5. **CI/CD**: Jenkins server, ECR repositories, and deployment pipeline
6. **Monitoring**: CloudWatch dashboards, Prometheus, and Grafana
7. **Security**: WAF, GuardDuty, and SecurityHub

## Getting Started

### Prerequisites

- [Terraform](https://www.terraform.io/downloads.html) (v1.0+)
- [AWS CLI](https://aws.amazon.com/cli/) configured with appropriate credentials
- SSH key pair for EC2 instances

### Deployment Steps

1. Clone this repository:

   ```bash
   git clone https://github.com/yourusername/ecs-jenkins-github.git
   cd ecs-jenkins-github
   ```

2. Set up the environment-specific variables:

   ```bash
   cd environments/dev
   cp terraform.tfvars.example terraform.tfvars
   ```

3. Edit `terraform.tfvars` with your specific values.

4. Initialize Terraform:

   ```bash
   terraform init
   ```

5. Create the infrastructure:

   ```bash
   terraform apply
   ```

### Post-Deployment Steps

1. Access the Jenkins server using the output URL and complete setup
2. Configure GitHub webhooks to trigger the CI/CD pipeline
3. Deploy your containerized application

## Module Details

### Network Module

Sets up a VPC with public, private, and database subnets across multiple availability zones, including all necessary routing and security groups.

### IAM Module

Creates IAM roles and policies for ECS tasks, Jenkins instances, and other AWS services, following the principle of least privilege.

### ECS Module

Deploys an ECS cluster with EC2 instances, task definitions, services, and an Application Load Balancer for high availability and scalability.

### Database Module

Creates an RDS instance with appropriate security groups, parameter groups, and backup configurations.

### CI/CD Module

Sets up a Jenkins server, ECR repositories, and CodeDeploy applications for continuous integration and deployment.

### Monitoring Module

Configures CloudWatch dashboards, alarms, and optionally deploys Prometheus and Grafana for comprehensive monitoring.

### Security Module

Implements WAF for the Application Load Balancer, enables GuardDuty for threat detection, and sets up SecurityHub for security monitoring.

## Environment Management

The project supports multiple environments:

- **Development (dev)**: For development and testing
- **Production (prod)**: For production workloads
- **Disaster Recovery (dr-pilot-light)**: For business continuity

Each environment has its own configuration in the `environments` directory.

## License

This project is licensed under the MIT License - see the LICENSE file for details.