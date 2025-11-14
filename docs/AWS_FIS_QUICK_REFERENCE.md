# AWS Fault Injection Simulator (FIS) Quick Reference Guide

This quick reference provides essential information for running AWS FIS experiments in the ECS/EC2/Jenkins infrastructure.

## Key Resources

- **Full Documentation**: [AWS FIS Playbook](./AWS_FIS_PLAYBOOK.md)
- **Experiment Templates**: `scripts/fis_templates/`
- **Setup Script**: `scripts/aws_fis_setup.sh`
- **Execution Script**: `scripts/run_fis_experiment.sh`
- **Report Template**: `docs/templates/fis_experiment_report_template.md`

## Available Experiment Types

| Experiment Type | Description | Template File | Target Resources |
|----------------|-------------|---------------|------------------|
| ECS Task Termination | Terminates random ECS tasks | `ecs_task_failure.json` | ECS Tasks |
| EC2 CPU Stress | Stresses CPU on EC2 instances | `ec2_cpu_stress.json` | EC2 Instances |
| RDS Failover | Forces RDS multi-AZ failover | *(See Playbook)* | RDS Database |
| Network Latency | Introduces network delays | *(See Playbook)* | EC2 Instances |
| ElastiCache Node Failover | Reboots cache nodes | *(See Playbook)* | ElastiCache Clusters |

## Quick Start

### 1. Setup

```bash
# First-time setup
cd scripts
chmod +x aws_fis_setup.sh
./aws_fis_setup.sh
```

### 2. Run an Experiment

```bash
# Make script executable
chmod +x run_fis_experiment.sh

# Run experiment with template ID from setup
./run_fis_experiment.sh -t exp-1234abcd5678efgh
```

### 3. Monitor Experiment

- Check the console output from the script
- View CloudWatch dashboard (see AWS FIS Playbook for template)
- Monitor application metrics and logs

### 4. Document Results

1. Create a report using the template:
   ```bash
   cp docs/templates/fis_experiment_report_template.md docs/reports/fis-experiment-YYYY-MM-DD.md
   ```
2. Fill in the report with results and observations
3. Share with the team

## Common Commands

```bash
# List experiment templates
aws fis list-experiment-templates

# Get experiment details
aws fis get-experiment --id experiment-1234abcd5678efgh

# Stop a running experiment
aws fis stop-experiment --id experiment-1234abcd5678efgh --reason "Manual stop"
```

## Safety Guidelines

1. **Start Small**: Begin with dev environment and minimal impact
2. **Stop Conditions**: Always configure appropriate CloudWatch alarms
3. **Monitoring**: Have proper monitoring in place before experiments
4. **Notification**: Notify stakeholders before running experiments
5. **Rollback Plan**: Document rollback steps for each experiment

## Integration with CI/CD

- Schedule regular experiments as part of resilience testing
- Include experiment results in system health reporting
- Automate experiment execution for dev/test environments
- Block production deployments if resilience tests fail

## AWS FIS Best Practices

1. Use resource tagging for precise targeting
2. Prefer percentage-based selection in production
3. Start with COUNT(1) for initial validation
4. Always exclude critical infrastructure components
5. Document all experiments using the provided templates

For detailed implementation instructions, experiment configurations, and comprehensive documentation, refer to the [AWS FIS Playbook](./AWS_FIS_PLAYBOOK.md).