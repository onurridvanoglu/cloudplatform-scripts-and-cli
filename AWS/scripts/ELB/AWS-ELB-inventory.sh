#!/bin/bash

# Add error handling
set -euo pipefail

# Add logging
exec 1> >(tee "elb_inventory_$(date +%Y%m%d_%H%M%S).log")
exec 2>&1

# Function to display help message
show_help() {
    echo "Usage: $0 [OPTIONS]"
    echo "Generate AWS Elastic Load Balancer inventory for specified region"
    echo ""
    echo "Options:"
    echo "  -h, --help           Show this help message"
    echo "  -r, --region         AWS region (required)"
    echo "  -o, --output FILE    Specify output file (default: aws-elb-inventory_TIMESTAMP.csv)"
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
    output_file="aws-elb-inventory_${region}_$(date +%Y%m%d_%H%M%S).csv"
fi

# Verify AWS CLI access
if ! aws sts get-caller-identity &>/dev/null; then
    show_progress "Error: Unable to authenticate with AWS CLI"
    exit 1
fi

show_progress "Starting ELB inventory for region: $region"

# Create CSV header
echo "Load Balancer Name,Type,Scheme,VPC ID,State,DNS Name,Created Time,AZ Count,Security Groups,Listeners,Target Groups,Tags" > "$output_file"

# Get list of load balancers
show_progress "Fetching Load Balancers..."

aws elbv2 describe-load-balancers \
    --region "$region" \
    --query 'LoadBalancers[].[
        LoadBalancerName,
        Type,
        Scheme,
        VpcId,
        State.Code,
        DNSName,
        CreatedTime,
        length(AvailabilityZones)
    ]' \
    --output text | while IFS=$'\t' read -r lb_name lb_type scheme vpc_id state dns_name created_time az_count; do
    
    show_progress "Processing Load Balancer: $lb_name"

    # Get Load Balancer ARN
    lb_arn=$(aws elbv2 describe-load-balancers \
        --region "$region" \
        --names "$lb_name" \
        --query 'LoadBalancers[0].LoadBalancerArn' \
        --output text)

    # Get security groups (if applicable)
    security_groups="N/A"
    if [[ "$lb_type" == "application" ]]; then
        security_groups=$(aws elbv2 describe-load-balancers \
            --region "$region" \
            --names "$lb_name" \
            --query 'LoadBalancers[0].SecurityGroups[]' \
            --output text | tr '\t' ',')
    fi

    # Get listeners with string conversion for port numbers
    listeners=$(aws elbv2 describe-listeners \
        --region "$region" \
        --load-balancer-arn "$lb_arn" \
        --query 'Listeners[].[join(`:`,[Protocol,to_string(Port)])]' \
        --output text | tr '\t' ',' || echo "None")

    # Get target groups
    target_groups=$(aws elbv2 describe-target-groups \
        --region "$region" \
        --load-balancer-arn "$lb_arn" \
        --query 'TargetGroups[].[TargetGroupName]' \
        --output text | tr '\t' ',' || echo "None")

    # Get tags
    tags=""
    if tag_info=$(aws elbv2 describe-tags \
        --region "$region" \
        --resource-arns "$lb_arn" \
        --query 'TagDescriptions[0].Tags[].[join(`=`,[Key,Value])]' \
        --output text 2>/dev/null); then
        tags=$(echo "$tag_info" | tr '\n' ',' | sed 's/,$//')
    fi

    # Handle null values
    scheme=${scheme:-"N/A"}
    vpc_id=${vpc_id:-"N/A"}
    
    # Output to CSV with proper quoting
    printf "%s,%s,%s,%s,%s,%s,%s,%s,%s,\"%s\",\"%s\",\"%s\"\n" \
        "$lb_name" \
        "$lb_type" \
        "$scheme" \
        "$vpc_id" \
        "$state" \
        "$dns_name" \
        "$created_time" \
        "$az_count" \
        "$security_groups" \
        "$listeners" \
        "$target_groups" \
        "$tags" >> "$output_file"
    
    show_progress "Processed Load Balancer: $lb_name"
done

show_progress "Inventory complete! Output saved to: $output_file" 