#!/bin/bash

# Set error handling
set -o pipefail

# Fixed values
REGION="eu-west-1"
COST_CENTER_VALUE="BT"
LOG_FILE="ecr_tagging_$(date +%Y%m%d_%H%M%S).log"

# Function to log messages
log_message() {
    local message="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "$timestamp - $message" | tee -a "$LOG_FILE"
}

# Function to check AWS CLI availability
check_aws_cli() {
    if ! command -v aws &> /dev/null; then
        log_message "ERROR: AWS CLI is not installed. Please install it first."
        exit 1
    fi
}

# Function to check AWS credentials
check_aws_credentials() {
    if ! aws sts get-caller-identity &> /dev/null; then
        log_message "ERROR: AWS credentials not configured or invalid."
        exit 1
    fi
}

# Function to tag a repository
tag_repository() {
    local repo_arn="$1"
    local repo_name=$(echo "$repo_arn" | awk -F':repository/' '{print $2}')
    
    # Check if CostCenter tag exists
    local list_tags_output
    list_tags_output=$(aws ecr list-tags-for-resource \
        --region "$REGION" \
        --resource-arn "$repo_arn" \
        --query 'tags[?Key==`CostCenter`]' \
        --output text 2>&1)
    local list_tags_status=$?
    
    if [ $list_tags_status -ne 0 ]; then
        log_message "ERROR: Failed to list tags: $list_tags_output"
        return 2
    fi
    
    if [ -z "$list_tags_output" ]; then
        # Add CostCenter tag
        local tag_output
        tag_output=$(aws ecr tag-resource \
            --region "$REGION" \
            --resource-arn "$repo_arn" \
            --tags "Key=CostCenter,Value=$COST_CENTER_VALUE" 2>&1)
        local tag_status=$?
        
        if [ $tag_status -eq 0 ]; then
            log_message "SUCCESS: Added CostCenter:BT tag to repository: $repo_name"
            return 0
        else
            log_message "ERROR: Failed to tag repository: $repo_name"
            log_message "ERROR: $tag_output"
            return 2
        fi
    else
        log_message "SKIPPED: Repository already has CostCenter tag: $repo_name"
        return 1
    fi
}

main() {
    log_message "Starting ECR repository tagging script in eu-west-1..."
    
    # Check prerequisites
    check_aws_cli
    check_aws_credentials
    
    # Get list of all repository ARNs
    log_message "Retrieving list of ECR repositories..."
    
    local repos=$(aws ecr describe-repositories \
        --region "$REGION" \
        --query 'repositories[*].repositoryArn' \
        --output text | tr -s '[:space:]' '\n' | grep -v '^$')
    
    if [ -z "$repos" ]; then
        log_message "No repositories found in eu-west-1"
        exit 0
    fi
    
    # Process each repository
    repo_count=0
    tagged_count=0
    skipped_count=0
    error_count=0
    
    while IFS= read -r repo_arn; do
        if [ -n "$repo_arn" ]; then
            ((repo_count++))
            log_message "Processing repository: $(echo "$repo_arn" | awk -F':repository/' '{print $2}')"
            
            tag_repository "$repo_arn"
            ret=$?
            
            case $ret in
                0) ((tagged_count++));;
                1) ((skipped_count++));;
                2) ((error_count++));;
            esac
        fi
    done <<< "$repos"
    
    # Print summary
    log_message "===== Summary ====="
    log_message "Total repositories processed: $repo_count"
    log_message "Successfully tagged: $tagged_count"
    log_message "Skipped (already tagged): $skipped_count"
    log_message "Errors encountered: $error_count"
    log_message "Log file: $LOG_FILE"
}

# Execute main function
main