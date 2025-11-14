# AWS Fault Injection Simulator (FIS) - Dev Environment Quick Reference

## Overview

This quick reference guide provides essential commands and procedures for running AWS FIS experiments in the **development environment only**. AWS FIS enables controlled chaos engineering experiments to test application and infrastructure resilience.

## 🚀 Getting Started (Dev Only)

### Initial Setup

```bash
# Clone the repository (if needed)
git clone <repository-url>

# Run the setup script to create IAM roles, CloudWatch alarms, and experiment templates
cd <project-directory>
chmod +x scripts/setup_aws_fis_dev.sh
./scripts/setup_aws_fis_dev.sh
```

### Experiment Templates

| Experiment Type | Description | Target | Duration |
|----------------|-------------|--------|----------|
| CPU Stress | Stress test CPU on EC2 instances | EC2 instances in ECS cluster | 5 minutes |
| Task Termination | Terminate ECS tasks | ECS tasks in dev service | Immediate |
| Network Latency | Add network latency | EC2 instances in ECS cluster | 5 minutes |

## 🧪 Running Experiments (Dev Only)

### CLI Method

```bash
# List available experiment templates
aws fis list-experiment-templates --query "experimentTemplates[*].{id:id,description:description,tags:tags}"

# Run a specific experiment
chmod +x scripts/run_dev_fis_experiment.sh
./scripts/run_dev_fis_experiment.sh <experiment-template-id> "Optional description"

# Check experiment status
aws fis get-experiment --id <experiment-id>

# Stop an experiment (if needed)
aws fis stop-experiment --id <experiment-id> --reason "Stopping test experiment"
```

### Jenkins Method

1. Navigate to Jenkins
2. Find the "Dev-FIS-Experiments" job
3. Click "Build with Parameters"
4. Select the experiment type
5. Add an optional description
6. Click "Build"

## 📊 Monitoring Experiments

### CloudWatch Dashboard

1. Open AWS Console
2. Go to CloudWatch > Dashboards
3. Select "DevFISExperiments" dashboard
4. Monitor metrics during and after experiments

### Logs and Reports

```bash
# View experiment logs
ls -la logs/fis/experiment-*.log

# View experiment reports
ls -la logs/fis/report-*.md
```

## ⚠️ Safety Controls

All experiments in the dev environment include these safety controls:

1. Resource targeting by tag: `Environment=dev`
2. Automatic stop conditions via CloudWatch alarms
3. Maximum experiment duration: 30 minutes
4. Limited to non-critical services

## 🛑 Emergency Stop

If you need to stop all experiments immediately:

```bash
# List running experiments
aws fis list-experiments --query "experiments[?state.status=='running']"

# Stop all running experiments
for id in $(aws fis list-experiments --query "experiments[?state.status=='running'].id" --output text); do
  aws fis stop-experiment --id $id --reason "Emergency stop"
done
```

## 📝 Documentation

For more details, see:
- [AWS FIS Dev Playbook](./AWS_FIS_DEV_PLAYBOOK.md)
- [AWS FIS User Guide](https://docs.aws.amazon.com/fis/latest/userguide/what-is.html)

## ✅ Pre-Experiment Checklist

- [ ] Confirm you are targeting **DEV environment only**
- [ ] Verify dev environment is in a healthy state
- [ ] Ensure monitoring dashboard is accessible
- [ ] Notify team members before running experiments
- [ ] Verify experiment template parameters and targets 
- [ ] Check stop conditions are properly configured
- [ ] Prepare to document observations and learnings

## 🚫 Restrictions

- **DO NOT** run these experiments in production
- **DO NOT** modify experiment templates without approval
- **DO NOT** disable stop conditions
- **DO NOT** increase experiment duration beyond 30 minutes