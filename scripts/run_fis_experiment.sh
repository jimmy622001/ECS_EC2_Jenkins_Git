#!/bin/bash
# AWS Fault Injection Simulator (FIS) Experiment Runner
# This script runs and monitors FIS experiments

set -e

# Check for AWS CLI installation
if ! command -v aws &>/dev/null; then
    echo "AWS CLI is not installed. Please install it first."
    exit 1
fi

# Check if jq is installed
if ! command -v jq &>/dev/null; then
    echo "jq is not installed. Please install it first."
    exit 1
fi

# Default values
TEMPLATE_ID=""
TAG_KEY="Purpose"
TAG_VALUE="Resilience-Testing"
MONITOR_INTERVAL=30  # seconds
TIMEOUT=3600  # 1 hour in seconds

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
        -t|--template-id)
            TEMPLATE_ID="$2"
            shift # past argument
            shift # past value
            ;;
        -k|--tag-key)
            TAG_KEY="$2"
            shift # past argument
            shift # past value
            ;;
        -v|--tag-value)
            TAG_VALUE="$2"
            shift # past argument
            shift # past value
            ;;
        -i|--interval)
            MONITOR_INTERVAL="$2"
            shift # past argument
            shift # past value
            ;;
        -m|--max-time)
            TIMEOUT="$2"
            shift # past argument
            shift # past value
            ;;
        -h|--help)
            echo "Usage: $0 [options]"
            echo "Options:"
            echo "  -t, --template-id TEMPLATE_ID    FIS experiment template ID (required)"
            echo "  -k, --tag-key KEY                Tag key for experiment (default: 'Purpose')"
            echo "  -v, --tag-value VALUE            Tag value for experiment (default: 'Resilience-Testing')"
            echo "  -i, --interval SECONDS           Monitoring interval in seconds (default: 30)"
            echo "  -m, --max-time SECONDS           Maximum experiment runtime in seconds (default: 3600)"
            echo "  -h, --help                       Show this help message"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Validate required parameters
if [ -z "$TEMPLATE_ID" ]; then
    echo "Error: Experiment template ID is required."
    echo "Use -t or --template-id to specify the template ID."
    exit 1
fi

echo "==== AWS FIS Experiment Runner ===="
echo "Template ID: $TEMPLATE_ID"
echo "Tag: $TAG_KEY=$TAG_VALUE"
echo "Monitoring interval: $MONITOR_INTERVAL seconds"
echo "Maximum runtime: $TIMEOUT seconds"

# Start the experiment
echo -e "\nStarting FIS experiment..."
EXPERIMENT_ID=$(aws fis start-experiment \
    --experiment-template-id "$TEMPLATE_ID" \
    --tags "$TAG_KEY=$TAG_VALUE" \
    --query 'experiment.id' \
    --output text)

echo "Experiment started with ID: $EXPERIMENT_ID"

# Function to get experiment state
get_experiment_state() {
    aws fis get-experiment \
        --id "$EXPERIMENT_ID" \
        --query 'experiment.state' \
        --output text
}

# Function to get experiment details
get_experiment_details() {
    aws fis get-experiment \
        --id "$EXPERIMENT_ID" \
        --output json
}

# Monitor experiment progress
echo -e "\nMonitoring experiment progress..."
echo "Press Ctrl+C to stop monitoring (experiment will continue)"

START_TIME=$(date +%s)
ELAPSED=0

# Print header
printf "%-20s %-15s %-30s\n" "Timestamp" "State" "Elapsed Time"
printf "%.s-" {1..70}
printf "\n"

# Monitor loop
while [ $ELAPSED -lt $TIMEOUT ]; do
    CURRENT_TIME=$(date +%s)
    ELAPSED=$((CURRENT_TIME - START_TIME))
    
    STATE=$(get_experiment_state)
    TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
    
    # Format elapsed time as HH:MM:SS
    ELAPSED_FORMAT=$(printf "%02d:%02d:%02d" $((ELAPSED/3600)) $((ELAPSED%3600/60)) $((ELAPSED%60)))
    
    printf "%-20s %-15s %-30s\n" "$TIMESTAMP" "$STATE" "$ELAPSED_FORMAT"
    
    # Exit loop if experiment is no longer running
    if [[ "$STATE" == "completed" || "$STATE" == "failed" || "$STATE" == "stopped" || "$STATE" == "cancelled" ]]; then
        break
    fi
    
    sleep $MONITOR_INTERVAL
done

# Get final experiment state
FINAL_STATE=$(get_experiment_state)
echo -e "\nExperiment finished with state: $FINAL_STATE"

# Print experiment details
echo -e "\nExperiment Details:"
get_experiment_details | jq '.experiment'

# Analysis summary
echo -e "\nExperiment Analysis:"
if [[ "$FINAL_STATE" == "completed" ]]; then
    echo "✅ Experiment completed successfully"
    echo "- Duration: $ELAPSED_FORMAT"
    echo "- Next steps: Check logs and metrics to analyze impact"
elif [[ "$FINAL_STATE" == "stopped" ]]; then
    echo "⚠️ Experiment was stopped"
    echo "- This might be due to stop conditions being met"
    echo "- Check CloudWatch alarms and logs to understand why"
elif [[ "$FINAL_STATE" == "failed" ]]; then
    echo "❌ Experiment failed"
    echo "- Check the experiment details for errors"
    echo "- Verify IAM permissions and resource availability"
else
    echo "Unexpected state: $FINAL_STATE"
    echo "- Review experiment details for more information"
fi

echo -e "\nTo see metrics impact, check CloudWatch dashboards."
echo "Experiment ID for reference: $EXPERIMENT_ID"