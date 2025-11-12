# Configure additional providers for cross-region replication
# We need to define DR region provider for when this module is used from the primary region

provider "aws" {
  alias = "dr_region"
  region = var.dr_region != "" ? var.dr_region : "eu-west-1" # Default to eu-west-1 if not specified
}