# Usage Instructions

This document provides detailed instructions on how to use and deploy the ECS with Jenkins CI/CD infrastructure.

## Prerequisites

Before getting started, ensure you have the following installed and configured:

- AWS CLI (version 2.0+) with appropriate IAM permissions
- Terraform (version 1.0+)
- Git (version 2.0+)
- A valid AWS account with access to create all required resources

## Initial Setup

### 1. Clone the Repository

```bash
git clone https://github.com/your-organization/ECS_EC2_Jenkins_Git.git
cd ECS_EC2_Jenkins_Git
```

### 2. Configure AWS Credentials

Ensure your AWS credentials are properly configured:

```bash
aws configure
```

Or set environment variables:

```bash
export AWS_ACCESS_KEY_ID="your-access-key"
export AWS_SECRET_ACCESS_KEY="your-secret-key"
export AWS_DEFAULT_REGION="your-region"
```

### 3. Configure Environment Variables

Each environment (dev, prod, dr-pilot-light) has its own configuration file:

1. Navigate to the environment directory:
   ```bash
   cd environments/dev
   ```

2. Copy the example variables file and edit it:
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   ```

3. Edit the `terraform.tfvars` file with your specific configuration.

### 4. Set Up Secrets

For secure handling of secrets, use the provided script:

```bash
# For Linux/macOS
./scripts/setup_secrets.sh dev

# For Windows
scripts\setup_secrets.bat dev
```

This script will prompt for required secrets and store them in AWS Secrets Manager.

## Deployment Options

### Option 1: Deploy All Components at Once

To deploy all infrastructure components at once for a specific environment:

```bash
cd environments/dev
./deploy_infrastructure.sh all   # For Linux/macOS
deploy_infrastructure.bat all   # For Windows
```

### Option 2: Deploy Individual Modules

For a more controlled deployment, deploy modules individually in the recommended order:

```bash
# For Linux/macOS
./deploy_infrastructure.sh network
./deploy_infrastructure.sh iam
./deploy_infrastructure.sh ecs
./deploy_infrastructure.sh database
./deploy_infrastructure.sh cicd
./deploy_infrastructure.sh monitoring
./deploy_infrastructure.sh security

# For Windows
deploy_infrastructure.bat network
deploy_infrastructure.bat iam
...and so on
```

### Option 3: Using Terraform Directly

You can also use Terraform commands directly for more control:

```bash
cd environments/dev
terraform init
terraform plan -out=tfplan
terraform apply tfplan
```

## Layered Deployment Approach

For a production environment, we recommend following the layered approach:

1. Deploy the infrastructure layer first:
   ```bash
   cd infrastructure/environments/prod
   terraform init && terraform apply
   ```

2. Then deploy the cluster layer:
   ```bash
   cd cluster/environments/prod
   terraform init && terraform apply
   ```

3. Finally, deploy the application layer:
   ```bash
   cd application/environments/prod
   terraform init && terraform apply
   ```

## Accessing Jenkins CI/CD

After deployment, you can access the Jenkins instance:

1. Get the Jenkins URL from the outputs:
   ```bash
   cd environments/dev
   terraform output jenkins_url
   ```

2. The initial admin password can be retrieved using:
   ```bash
   terraform output jenkins_initial_password
   ```

3. Follow the on-screen instructions to complete Jenkins setup

## Deploying Applications

To deploy applications to your new infrastructure:

1. Create a Dockerfile and required application files in a GitHub repository
2. Configure Jenkins to build and deploy to the ECS cluster:
   - Create a new pipeline in Jenkins
   - Connect it to your GitHub repository
   - Use the provided Jenkinsfile templates in `application/pipelines/`

## Monitoring Your Infrastructure

Access your Grafana dashboard to monitor the infrastructure:

1. Get the Grafana URL:
   ```bash
   terraform output grafana_url
   ```

2. Log in with the credentials stored in AWS Secrets Manager

## Common Tasks

### Scaling Your ECS Cluster

To adjust the capacity of your ECS cluster:

1. Modify `min_capacity` and `max_capacity` in your environment's `terraform.tfvars` file
2. Apply the changes:
   ```bash
   cd environments/dev
   terraform apply
   ```

### Updating Container Definitions

To update the container definitions:

1. Edit the container definitions in the relevant environment's `terraform.tfvars` file
2. Apply the changes:
   ```bash
   cd environments/dev
   terraform apply
   ```

### Rotating Database Credentials

To rotate database credentials:

1. Update the secrets in AWS Secrets Manager
2. Redeploy the ECS service to pick up the new credentials:
   ```bash
   aws ecs update-service --cluster <cluster-name> --service <service-name> --force-new-deployment
   ```

## Cleanup

To destroy the infrastructure when no longer needed:

```bash
cd environments/dev
terraform destroy
```

**Note**: This will destroy all resources created by Terraform in the specified environment.

## Troubleshooting

### Common Issues

1. **Deployment Failures**
   - Check CloudWatch Logs for specific error messages
   - Ensure IAM permissions are correctly configured
   - Validate your VPC and subnet configurations

2. **Container Deployment Issues**
   - Verify that your container image exists in the ECR repository
   - Check ECS service events in the AWS Console
   - Examine task definition parameters for compatibility issues

3. **Jenkins Connection Problems**
   - Ensure security groups allow traffic on port 8080
   - Verify the EC2 instance is running
   - Check the instance's system log for boot errors

### Getting Help

If you encounter issues not covered in this guide:

1. Check the AWS documentation for specific services
2. Review the Terraform documentation for module details
3. Open an issue in the project's GitHub repository