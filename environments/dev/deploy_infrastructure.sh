#!/bin/bash

# Script for deploying infrastructure components individually

# Exit on any error
set -e

# Function for displaying usage information
function usage {
  echo "Usage: $0 [component]"
  echo "Components:"
  echo "  network    - Deploy network infrastructure only"
  echo "  iam        - Deploy IAM roles and policies only"
  echo "  ecs        - Deploy ECS cluster and services only"
  echo "  database   - Deploy RDS database only"
  echo "  cicd       - Deploy CI/CD pipeline components only"
  echo "  monitoring - Deploy monitoring solutions only"
  echo "  security   - Deploy security components only"
  echo "  all        - Deploy all components (default)"
  exit 1
}

# Get the component to deploy
COMPONENT=${1:-all}

# Validate component
case $COMPONENT in
  network|iam|ecs|database|cicd|monitoring|security|all)
    ;;
  *)
    echo "Invalid component: $COMPONENT"
    usage
    ;;
esac

echo "Deploying component: $COMPONENT"

# Define TF_VAR for component selection
if [ "$COMPONENT" != "all" ]; then
  export TF_VAR_deploy_network=$([ "$COMPONENT" = "network" ] || [ "$COMPONENT" = "all" ] && echo "true" || echo "false")
  export TF_VAR_deploy_iam=$([ "$COMPONENT" = "iam" ] || [ "$COMPONENT" = "all" ] && echo "true" || echo "false")
  export TF_VAR_deploy_ecs=$([ "$COMPONENT" = "ecs" ] || [ "$COMPONENT" = "all" ] && echo "true" || echo "false")
  export TF_VAR_deploy_database=$([ "$COMPONENT" = "database" ] || [ "$COMPONENT" = "all" ] && echo "true" || echo "false")
  export TF_VAR_deploy_cicd=$([ "$COMPONENT" = "cicd" ] || [ "$COMPONENT" = "all" ] && echo "true" || echo "false")
  export TF_VAR_deploy_monitoring=$([ "$COMPONENT" = "monitoring" ] || [ "$COMPONENT" = "all" ] && echo "true" || echo "false")
  export TF_VAR_deploy_security=$([ "$COMPONENT" = "security" ] || [ "$COMPONENT" = "all" ] && echo "true" || echo "false")
else
  # Deploy all components
  export TF_VAR_deploy_network=true
  export TF_VAR_deploy_iam=true
  export TF_VAR_deploy_ecs=true
  export TF_VAR_deploy_database=true
  export TF_VAR_deploy_cicd=true
  export TF_VAR_deploy_monitoring=true
  export TF_VAR_deploy_security=true
fi

# Check if terraform.tfvars exists
if [ ! -f "terraform.tfvars" ]; then
  echo "Warning: terraform.tfvars not found!"
  echo "Please create it from terraform.tfvars.example before deploying."
  exit 1
fi

# Initialize Terraform if not already done
if [ ! -d ".terraform" ]; then
  echo "Initializing Terraform..."
  terraform init
fi

# Create plan
echo "Creating Terraform plan..."
terraform plan -out=tfplan

# Apply the plan
echo "Applying Terraform plan..."
terraform apply tfplan

echo "Deployment of component '$COMPONENT' completed successfully!"