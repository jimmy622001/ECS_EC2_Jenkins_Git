# AWS FIS Experiment Report

## Experiment Overview

**Experiment ID:** [FIS Experiment ID]  
**Template ID:** [Template ID]  
**Execution Date:** [YYYY-MM-DD]  
**Duration:** [HH:MM:SS]  
**Environment:** [dev/staging/prod]  

**Experiment Objective:**  
[Brief description of what the experiment was trying to validate]

**Target Resources:**
- Resource Type: [e.g., EC2 instances, ECS tasks]
- Selection Criteria: [e.g., specific tags, count]
- Affected Components: [List specific resources that were affected]

## Experiment Actions

| Action ID | Action Type | Target | Parameters | Duration |
|-----------|-------------|--------|------------|----------|
| [ID] | [e.g., aws:ec2:stop-instances] | [Target Resource] | [Key Parameters] | [Duration] |

## Experiment Outcome

**Final State:** [completed/failed/stopped/cancelled]  
**Stop Condition Triggered:** [Yes/No - Which one if applicable]  

**Key Observations:**
1. [Observation 1]
2. [Observation 2]
3. [Observation 3]

## Metrics Analysis

### Service Health Metrics

| Metric | Baseline | During Experiment | Recovery | % Change | Recovery Time |
|--------|----------|-------------------|----------|----------|---------------|
| API Response Time (p99) | [Value] | [Value] | [Value] | [%] | [Time] |
| Error Rate | [Value] | [Value] | [Value] | [%] | [Time] |
| Success Rate | [Value] | [Value] | [Value] | [%] | [Time] |

### Resource Utilization

| Resource | Metric | Baseline | Peak | Recovery | Notes |
|----------|--------|----------|------|----------|-------|
| ECS Cluster | CPU | [Value] | [Value] | [Value] | [Notes] |
| ECS Cluster | Memory | [Value] | [Value] | [Value] | [Notes] |
| RDS | Connections | [Value] | [Value] | [Value] | [Notes] |
| ElastiCache | CPU | [Value] | [Value] | [Value] | [Notes] |

### Application Performance

| Transaction Type | Baseline Latency | Experiment Latency | Recovery Latency | Impact |
|------------------|-----------------|-------------------|-----------------|--------|
| API GET Requests | [Value] | [Value] | [Value] | [High/Medium/Low] |
| API POST Requests | [Value] | [Value] | [Value] | [High/Medium/Low] |
| Database Queries | [Value] | [Value] | [Value] | [High/Medium/Low] |

## Recovery Analysis

**Auto-Healing Mechanisms:**
- [Mechanism 1]: [Effective/Partially Effective/Not Effective]
- [Mechanism 2]: [Effective/Partially Effective/Not Effective]

**Recovery Timeline:**
1. T+0:00: Experiment started
2. T+[Time]: [Event]
3. T+[Time]: [Event]
4. T+[Time]: Recovery complete

**Recovery Time Objectives (RTOs):**
- Target RTO: [Value]
- Actual Recovery Time: [Value]
- Within SLA: [Yes/No]

## Resilience Assessment

**Strengths:**
- [Strength 1]
- [Strength 2]
- [Strength 3]

**Weaknesses:**
- [Weakness 1]
- [Weakness 2]
- [Weakness 3]

**Resilience Score:** [1-10]

## Learnings and Recommendations

**Key Learnings:**
1. [Learning 1]
2. [Learning 2]
3. [Learning 3]

**Immediate Actions:**
1. [Action 1]
2. [Action 2]
3. [Action 3]

**Long-term Improvements:**
1. [Improvement 1]
2. [Improvement 2]
3. [Improvement 3]

## Follow-up Experiments

**Recommended Additional Tests:**
1. [Test 1]
2. [Test 2]
3. [Test 3]

## Appendix

### Experiment Configuration

```json
[Paste full experiment template JSON here]
```

### Logs and Events

```
[Paste relevant log snippets here]
```

### Screenshots

[Add links or embed screenshots of relevant dashboards/alerts]

## Sign-off

**Prepared by:** [Name]  
**Reviewed by:** [Name]  
**Approved by:** [Name]  

**Date:** [YYYY-MM-DD]