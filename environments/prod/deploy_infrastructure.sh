#!/bin/bash

# Script to deploy infrastructure in the production environment
echo "Deploying infrastructure for production environment..."

# Initialize Terraform
terraform init

# Plan the deployment
terraform plan -out=tfplan

# Ask for confirmation before applying
read -p "Do you want to continue with the deployment? (y/n) " -n 1 -r
echo    # Move to a new line
if [[ $REPLY =~ ^[Yy]$ ]]
then
  # Apply the Terraform plan
  terraform apply tfplan
  
  # Output the important values
  echo "Deployment completed. Key outputs:"
  terraform output
else
  echo "Deployment canceled."
fi