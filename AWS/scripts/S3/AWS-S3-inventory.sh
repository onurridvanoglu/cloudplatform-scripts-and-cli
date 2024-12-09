#!/bin/bash

# Add error handling
set -euo pipefail

# Add logging
exec 1> >(tee "s3_inventory_$(date +%Y%m%d_%H%M%S).log")
exec 2>&1

# Function to display help message
show_help() {
    echo "Usage: $0 [OPTIONS]"
    echo "Generate AWS S3 bucket inventory"
    echo ""
    echo "Options:"
    echo "  -h, --help           Show this help message"
    echo "  -o, --output FILE    Specify output file (default: aws-s3-inventory_TIMESTAMP.csv)"
    exit 0
}

# Function to show progress
show_progress() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Parse command line arguments
output_file=""

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
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

# Set default output file if not specified
if [[ -z "$output_file" ]]; then
    output_file="aws-s3-inventory_$(date +%Y%m%d_%H%M%S).csv"
fi

# Verify AWS CLI access
if ! aws sts get-caller-identity &>/dev/null; then
    show_progress "Error: Unable to authenticate with AWS CLI"
    exit 1
fi

show_progress "Starting S3 bucket inventory..."

# Create CSV header
echo "Bucket Name,Creation Date,Region,Versioning,Encryption,Public Access Blocked,Tags" > "$output_file"

# Get list of buckets
show_progress "Fetching S3 buckets..."

aws s3api list-buckets --query 'Buckets[].[Name,CreationDate]' --output text | while IFS=$'\t' read -r bucket_name creation_date; do
    show_progress "Processing bucket: $bucket_name"
    
    # Get bucket region
    region=$(aws s3api get-bucket-location --bucket "$bucket_name" --query 'LocationConstraint' --output text)
    region=${region:-"us-east-1"} # Default to us-east-1 if null
    
    # Get versioning status
    versioning=$(aws s3api get-bucket-versioning --bucket "$bucket_name" --query 'Status' --output text)
    versioning=${versioning:-"Disabled"}
    
    # Get encryption status
    encryption="Disabled"
    if aws s3api get-bucket-encryption --bucket "$bucket_name" &>/dev/null; then
        encryption="Enabled"
    fi
    
    # Get public access block status
    public_access="Enabled"
    if ! aws s3api get-public-access-block --bucket "$bucket_name" &>/dev/null; then
        public_access="Disabled"
    fi
    
    # Get tags with proper CSV formatting
    tags=""
    if tag_info=$(aws s3api get-bucket-tagging --bucket "$bucket_name" --query 'TagSet[].[join(`=`,[Key,Value])]' --output text 2>/dev/null); then
        tags=$(echo "$tag_info" | tr '\n' ',' | sed 's/,$//')
    fi
    
    # Output to CSV with tags properly quoted
    printf "%s,%s,%s,%s,%s,%s,\"%s\"\n" \
        "$bucket_name" \
        "$creation_date" \
        "$region" \
        "$versioning" \
        "$encryption" \
        "$public_access" \
        "$tags" >> "$output_file"
done

show_progress "Inventory complete! Output saved to: $output_file" 