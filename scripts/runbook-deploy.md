# Infrastructure Runbook Script

This directory contains scripts for testing and validating the ECS infrastructure across development and production environments.

## Main Script: `infrastructure_runbook.py`

This comprehensive Python script helps manage and test your infrastructure environments. It can:

- Validate environment configurations
- Test application health
- Check AWS resources
- Perform security audits
- Analyze CloudWatch logs
- Run load tests
- Compare environments
- Generate detailed reports

## Requirements

The script requires the following Python packages:
pip install boto3 requests tabulate


## Usage

### Basic Commands

```bash
# Validate environment configuration
./infrastructure_