#!/bin/bash

# Add error handling
set -euo pipefail

# Add logging
exec 1> >(tee "aws_inventory_all_$(date +%Y%m%d_%H%M%S).log")
exec 2>&1

# Function to display help message
show_help() {
    echo "Usage: $0 [OPTIONS]"
    echo "Generate comprehensive AWS inventory across all services"
    echo ""
    echo "Options:"
    echo "  -h, --help           Show help message"
    echo "  -r, --region         AWS region (required)"
    echo "  -o, --output-dir     Output directory (default: aws-inventory_TIMESTAMP)"
    exit 0
}

# Function to show progress
show_progress() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Parse command line arguments
output_dir=""
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
        -o|--output-dir)
            output_dir="$2"
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

# Set default output directory if not specified
if [[ -z "$output_dir" ]]; then
    output_dir="aws-inventory_$(date +%Y%m%d_%H%M%S)"
fi

# Create output directory
mkdir -p "$output_dir"

# Verify AWS CLI access
if ! aws sts get-caller-identity &>/dev/null; then
    show_progress "Error: Unable to authenticate with AWS CLI"
    exit 1
fi

show_progress "Starting comprehensive AWS inventory for region: $region"

# Function to run individual inventory scripts
run_inventory() {
    local service=$1
    local script_path=$2
    local output_file="$output_dir/${service,,}-inventory.csv"
    
    show_progress "Running $service inventory..."
    
    if [[ "$service" == "S3" || "$service" == "Route53" ]]; then
        # Global services don't need region parameter
        bash "$script_path" -o "$output_file"
    else
        # Regional services need region parameter
        bash "$script_path" -r "$region" -o "$output_file"
    fi
    
    if [[ $? -eq 0 ]]; then
        show_progress "$service inventory completed successfully"
    else
        show_progress "Warning: $service inventory completed with errors"
    fi
}

# Run individual inventory scripts
run_inventory "EC2" "EC2/AWS-EC2-inventory.sh"
run_inventory "RDS" "RDS/AWS-RDS-inventory.sh"
run_inventory "S3" "S3/AWS-S3-inventory.sh"
run_inventory "ELB" "ELB/AWS-ELB-inventory.sh"
run_inventory "Route53" "Route53/AWS-Route53-inventory.sh"

show_progress "Inventory complete! Output saved to: $output_dir"
show_progress "See individual CSV files for each service's inventory" 