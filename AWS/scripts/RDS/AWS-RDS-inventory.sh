#!/bin/bash

# Add error handling
set -euo pipefail

# Add logging
exec 1> >(tee "rds_inventory_$(date +%Y%m%d_%H%M%S).log")
exec 2>&1

# Function to display help message
show_help() {
    echo "Usage: $0 [OPTIONS]"
    echo "Generate AWS RDS instance inventory for specified region"
    echo ""
    echo "Options:"
    echo "  -h, --help           Show this help message"
    echo "  -r, --region         AWS region (required)"
    echo "  -o, --output FILE    Specify output file (default: aws-rds-inventory_TIMESTAMP.csv)"
    exit 0
}

# Function to show progress
show_progress() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Parse command line arguments
output_file=""
region=""

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            ;;
        -r|--region)
            region="$2"
            shift 2
            ;;
        -o|--output)
            output_file="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            show_help
            ;;
    esac
done

# Check if region is provided
if [[ -z "$region" ]]; then
    echo "Error: Region parameter is required"
    show_help
fi

# Set default output file if not specified
if [[ -z "$output_file" ]]; then
    output_file="aws-rds-inventory_${region}_$(date +%Y%m%d_%H%M%S).csv"
fi

# Verify AWS CLI access
if ! aws sts get-caller-identity &>/dev/null; then
    show_progress "Error: Unable to authenticate with AWS CLI"
    exit 1
fi

show_progress "Starting RDS inventory for region: $region"

# Create CSV header
echo "DB Instance ID,DB Instance Class,Engine,Engine Version,Status,Storage Type,Storage Size (GB),Multi-AZ,Publicly Accessible,Endpoint,Port,Creation Time,Backup Retention,Tags" > "$output_file"

# Get list of RDS instances
show_progress "Fetching RDS instances..."

aws rds describe-db-instances \
    --region "$region" \
    --query 'DBInstances[].[
        DBInstanceIdentifier,
        DBInstanceClass,
        Engine,
        EngineVersion,
        DBInstanceStatus,
        StorageType,
        AllocatedStorage,
        MultiAZ,
        PubliclyAccessible,
        Endpoint.Address,
        Endpoint.Port,
        InstanceCreateTime
    ]' \
    --output text | while IFS=$'\t' read -r instance_id instance_class engine engine_version status storage_type storage_size multi_az public_access endpoint port creation_time; do
    
    show_progress "Processing instance: $instance_id"

    # Get backup retention period
    backup_retention=$(aws rds describe-db-instances \
        --region "$region" \
        --db-instance-identifier "$instance_id" \
        --query 'DBInstances[0].BackupRetentionPeriod' \
        --output text)

    # Get tags with proper CSV formatting
    tags=""
    if tag_info=$(aws rds list-tags-for-resource \
        --region "$region" \
        --resource-name "arn:aws:rds:${region}:$(aws sts get-caller-identity --query 'Account' --output text):db:${instance_id}" \
        --query 'TagList[].[join(`=`,[Key,Value])]' \
        --output text 2>/dev/null); then
        tags=$(echo "$tag_info" | tr '\n' ',' | sed 's/,$//')
    fi

    # Handle null values
    endpoint=${endpoint:-"N/A"}
    port=${port:-"N/A"}
    
    # Output to CSV with tags properly quoted
    printf "%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,\"%s\"\n" \
        "$instance_id" \
        "$instance_class" \
        "$engine" \
        "$engine_version" \
        "$status" \
        "$storage_type" \
        "$storage_size" \
        "$multi_az" \
        "$public_access" \
        "$endpoint" \
        "$port" \
        "$creation_time" \
        "$backup_retention" \
        "$tags" >> "$output_file"
    
    show_progress "Processed instance: $instance_id"
done

show_progress "Inventory complete! Output saved to: $output_file" 