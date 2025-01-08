#!/bin/bash

# Add error handling
set -euo pipefail

# Add logging
exec 1> >(tee "ec2_inventory_$(date +%Y%m%d_%H%M%S).log")
exec 2>&1

# Function to display help message
show_help() {
    echo "Usage: $0 [OPTIONS]"
    echo "Generate AWS EC2 instance inventory for specified region"
    echo ""
    echo "Options:"
    echo "  -h, --help           Show this help message"
    echo "  -r, --region         AWS region (required)"
    echo "  -o, --output FILE    Specify output file (default: aws-ec2-inventory_TIMESTAMP.csv)"
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
    output_file="aws-ec2-inventory_${region}_$(date +%Y%m%d_%H%M%S).csv"
fi

# Verify AWS CLI access
if ! aws sts get-caller-identity &>/dev/null; then
    show_progress "Error: Unable to authenticate with AWS CLI"
    exit 1
fi

show_progress "Starting EC2 inventory for region: $region"

# Create CSV header
echo "Instance ID,Name,Instance Type,State,Private IP,Public IP,VPC ID,Subnet ID,Platform,CPU Count,Memory (GiB),Total Volume Size,Tags,Launch Time" > "$output_file"

# Get list of EC2 instances
show_progress "Fetching EC2 instances..."

aws ec2 describe-instances \
    --region "$region" \
    --query 'Reservations[].Instances[].[
        InstanceId,
        Tags[?Key==`Name`].Value | [0],
        InstanceType,
        State.Name,
        PrivateIpAddress,
        PublicIpAddress,
        VpcId,
        SubnetId,
        Platform,
        CpuOptions.CoreCount
    ]' \
    --output text | while IFS=$'\t' read -r instance_id name instance_type state private_ip public_ip vpc_id subnet_id platform cpu_count; do
    
    # Skip if instance_type is empty or invalid
    if [[ -z "$instance_type" || "$instance_type" == "None" ]]; then
        show_progress "Warning: Invalid instance type for instance $instance_id, skipping memory info"
        memory_gib="N/A"
    else
        # Get instance details
        instance_info=$(aws ec2 describe-instance-types \
            --region "$region" \
            --instance-types "$instance_type" \
            --query 'InstanceTypes[0].[MemoryInfo.SizeInMiB]' \
            --output text)
        
        memory_gib=$(awk -v mem="$instance_info" 'BEGIN {printf "%.1f", mem/1024}')
    fi

    # Get total volume size (sum of all volumes)
    total_volume_size=$(aws ec2 describe-volumes \
        --region "$region" \
        --filters "Name=attachment.instance-id,Values=$instance_id" \
        --query 'sum(Volumes[].Size)' \
        --output text)

    # Get all tags with proper CSV formatting
    tags=$(aws ec2 describe-tags \
        --region "$region" \
        --filters "Name=resource-id,Values=$instance_id" \
        --query 'Tags[].[join(`=`,[Key,Value])]' \
        --output text | tr '\n' ',' | sed 's/,$//')

    # Get launch time
    launch_time=$(aws ec2 describe-instances \
        --region "$region" \
        --instance-ids "$instance_id" \
        --query 'Reservations[].Instances[].LaunchTime' \
        --output text)

    # Handle null values
    name=${name:-"N/A"}
    public_ip=${public_ip:-"N/A"}
    platform=${platform:-"linux"}
    
    # Output to CSV with tags properly quoted
    printf "%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,\"%s\",%s\n" \
        "$instance_id" \
        "$name" \
        "$instance_type" \
        "$state" \
        "$private_ip" \
        "$public_ip" \
        "$vpc_id" \
        "$subnet_id" \
        "$platform" \
        "$cpu_count" \
        "$memory_gib" \
        "$total_volume_size" \
        "$tags" \
        "$launch_time" >> "$output_file"
    
    show_progress "Processed instance: $instance_id"
done

show_progress "Inventory complete! Output saved to: $output_file" 