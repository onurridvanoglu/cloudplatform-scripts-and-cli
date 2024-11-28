#!/bin/bash

set -euo pipefail  # Exit on error, undefined vars, and pipeline failures

# Function to log messages with timestamps
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1"
}

# Function to show usage
usage() {
    echo "Usage: $0 [-n NODEGROUP_NAME] [-t TAG_VALUE] [-d] [-h]"
    echo "  -n : NodeGroup name (required)"
    echo "  -t : CostCenter tag value (required)"
    echo "  -d : Dry run mode"
    echo "  -h : Show this help message"
    exit 1
}

# Parse command line arguments
DRY_RUN=false
while getopts "n:t:dh" opt; do
    case $opt in
        n) NODEGROUP_NAME="$OPTARG" ;;
        t) COST_CENTER_TAG="$OPTARG" ;;
        d) DRY_RUN=true ;;
        h) usage ;;
        *) usage ;;
    esac
done

# Validate required parameters
if [ -z "${NODEGROUP_NAME:-}" ] || [ -z "${COST_CENTER_TAG:-}" ]; then
    log "Error: NodeGroup name and CostCenter tag value are required"
    usage
fi

# Check AWS CLI availability and version
if ! command -v aws >/dev/null 2>&1; then
    log "Error: AWS CLI is not installed"
    exit 1
fi

# Function to tag resources
tag_resources() {
    local RESOURCE_TYPE=$1
    local RESOURCE_IDS=$2

    if [ -n "$RESOURCE_IDS" ]; then
        log "Tagging $RESOURCE_TYPE resources: $RESOURCE_IDS"
        if [ "$DRY_RUN" = true ]; then
            log "[DRY RUN] Would tag $RESOURCE_TYPE with CostCenter=$COST_CENTER_TAG"
        else
            if ! aws ec2 create-tags \
                --resources $RESOURCE_IDS \
                --tags "Key=CostCenter,Value=$COST_CENTER_TAG"; then
                log "Error: Failed to tag $RESOURCE_TYPE resources"
                return 1
            fi
            log "$RESOURCE_TYPE resources tagged successfully"
        fi
    else
        log "No $RESOURCE_TYPE resources found to tag"
    fi
}

# Main execution
log "Starting tagging process for NodeGroup: $NODEGROUP_NAME"

# Step 1: Get all instances in the NodeGroup
log "Fetching instances for NodeGroup"
INSTANCE_IDS=$(aws ec2 describe-instances \
    --filters "Name=tag:eks:nodegroup-name,Values=${NODEGROUP_NAME}" \
    --query "Reservations[*].Instances[*].InstanceId" \
    --output text)

if [ -z "$INSTANCE_IDS" ]; then
    log "Error: No instances found for NodeGroup: $NODEGROUP_NAME"
    exit 1
fi

# Step 2: Tag instances
log "Step 2: Tagging EC2 Instances"
tag_resources "Instance" "$INSTANCE_IDS"

# Step 3: Tag associated volumes for each instance
log "Step 3: Tagging Attached Volumes"
for INSTANCE_ID in $INSTANCE_IDS; do
    VOLUME_IDS=$(aws ec2 describe-volumes \
        --filters "Name=attachment.instance-id,Values=${INSTANCE_ID}" \
        --query "Volumes[*].VolumeId" \
        --output text)
    tag_resources "Volume" "$VOLUME_IDS"
done

log "Tagging process completed successfully"