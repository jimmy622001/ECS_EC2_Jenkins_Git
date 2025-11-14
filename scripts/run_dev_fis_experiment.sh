#!/bin/bash
# Run AWS FIS Experiment in Dev Environment
# This script runs a specified AWS FIS experiment and monitors its progress

set -e

# Check if experiment template ID is provided
if [ -z "$1" ]; then
  echo "Error: Experiment template ID is required"
  echo "Usage: run_dev_fis_experiment.sh <experiment-template-id> [description]"
  exit 1
fi

TEMPLATE_ID=$1
DESCRIPTION=${2:-"Dev environment FIS experiment"}
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
EXPERIMENT_NAME="dev-fis-${TIMESTAMP}"

echo "====== AWS FIS EXPERIMENT EXECUTION ======"
echo "Environment: Development"
echo "Template ID: ${TEMPLATE_ID}"
echo "Description: ${DESCRIPTION}"
echo "Timestamp: ${TIMESTAMP}"
echo "======================================="

# Create logs directory if it doesn't exist
mkdir -p logs/fis

# Start the experiment
echo "Starting FIS experiment..."
EXPERIMENT_OUTPUT=$(aws fis start-experiment \
  --experiment-template-id ${TEMPLATE_ID} \
  --tags Name=${EXPERIMENT_NAME})

EXPERIMENT_ID=$(echo $EXPERIMENT_OUTPUT | jq -r '.experiment.id')

echo "Experiment ID: ${EXPERIMENT_ID}"
echo "Experiment started at: $(date)"

# Write experiment details to log file
LOG_FILE="logs/fis/experiment-${EXPERIMENT_ID}-${TIMESTAMP}.log"
echo "Logging experiment details to: ${LOG_FILE}"

{
  echo "====== AWS FIS EXPERIMENT LOG ======"
  echo "Experiment ID: ${EXPERIMENT_ID}"
  echo "Template ID: ${TEMPLATE_ID}"
  echo "Description: ${DESCRIPTION}"
  echo "Start Time: $(date)"
  echo "======================================="
} >> ${LOG_FILE}

# Function to get experiment status
get_experiment_status() {
  aws fis get-experiment --id $1 --query 'experiment.state' --output text
}

# Monitor the experiment
echo "Monitoring experiment progress..."
STATUS=$(get_experiment_status ${EXPERIMENT_ID})
echo "Initial status: ${STATUS}"

while [ "${STATUS}" == "pending" ] || [ "${STATUS}" == "initiating" ] || [ "${STATUS}" == "running" ]; do
  echo "$(date +%H:%M:%S) - Experiment status: ${STATUS}"
  
  # Get more detailed information
  EXPERIMENT_DETAILS=$(aws fis get-experiment --id ${EXPERIMENT_ID})
  echo "${EXPERIMENT_DETAILS}" | jq -r '.experiment | "Actions: \(.actions | length), Start Time: \(.startTime)"' 
  
  # Log status with timestamp
  echo "$(date +%Y-%m-%d-%H:%M:%S) - Status: ${STATUS}" >> ${LOG_FILE}
  
  # Sleep for 10 seconds before checking again
  sleep 10
  
  # Update status
  STATUS=$(get_experiment_status ${EXPERIMENT_ID})
done

# Get final experiment details
EXPERIMENT_DETAILS=$(aws fis get-experiment --id ${EXPERIMENT_ID})
echo "Experiment completed with status: ${STATUS}"
echo "Experiment details:"
echo "${EXPERIMENT_DETAILS}" | jq -r '.experiment'

# Log final status and details
{
  echo "======= EXPERIMENT COMPLETION ========"
  echo "Final Status: ${STATUS}"
  echo "End Time: $(date)"
  echo "${EXPERIMENT_DETAILS}" | jq -r '.experiment'
  echo "======================================="
} >> ${LOG_FILE}

# Generate a summary report
REPORT_FILE="logs/fis/report-${EXPERIMENT_ID}-${TIMESTAMP}.md"
echo "Generating experiment report: ${REPORT_FILE}"

# Get details for the report
END_TIME=$(echo "${EXPERIMENT_DETAILS}" | jq -r '.experiment.endTime')
START_TIME=$(echo "${EXPERIMENT_DETAILS}" | jq -r '.experiment.startTime')
TEMPLATE_NAME=$(aws fis get-experiment-template --id ${TEMPLATE_ID} --query 'experimentTemplate.description' --output text)

{
  echo "# AWS FIS Experiment Report"
  echo ""
  echo "## Experiment Details"
  echo ""
  echo "- **Experiment ID:** ${EXPERIMENT_ID}"
  echo "- **Template ID:** ${TEMPLATE_ID}"
  echo "- **Template Description:** ${TEMPLATE_NAME}"
  echo "- **Environment:** Development"
  echo "- **Start Time:** ${START_TIME}"
  echo "- **End Time:** ${END_TIME}"
  echo "- **Status:** ${STATUS}"
  echo ""
  echo "## Actions Performed"
  echo ""
  echo "${EXPERIMENT_DETAILS}" | jq -r '.experiment.actions[] | "- **\(.name):** \(.description) - Status: \(.state.status)"'
  echo ""
  echo "## Targets"
  echo ""
  echo "${EXPERIMENT_DETAILS}" | jq -r '.experiment.targets[] | "- **\(.name):** ResourceType: \(.resourceType)"'
  echo ""
  echo "## Observations"
  echo ""
  echo "*(Add observations about system behavior during the experiment)*"
  echo ""
  echo "## Learnings"
  echo ""
  echo "*(Document key learnings from this experiment)*"
  echo ""
  echo "## Follow-up Actions"
  echo ""
  echo "*(Document any follow-up actions or improvements needed)*"
} > ${REPORT_FILE}

echo "Experiment completed. Report generated at ${REPORT_FILE}"
echo "View the CloudWatch dashboard for detailed metrics."