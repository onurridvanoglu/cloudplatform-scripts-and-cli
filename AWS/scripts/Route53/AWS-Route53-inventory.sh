#!/bin/bash

# Add error handling
set -euo pipefail

# Add logging
exec 1> >(tee "route53_inventory_$(date +%Y%m%d_%H%M%S).log")
exec 2>&1

# Function to display help message
show_help() {
    echo "Usage: $0 [OPTIONS]"
    echo "Generate AWS Route53 hosted zones inventory"
    echo ""
    echo "Options:"
    echo "  -h, --help           Show this help message"
    echo "  -o, --output FILE    Specify output file (default: aws-route53-inventory_TIMESTAMP.csv)"
    echo "  -d, --details        Include record details (optional)"
    exit 0
}

# Function to show progress
show_progress() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Parse command line arguments
output_file=""
include_records=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            ;;
        -o|--output)
            output_file="$2"
            shift 2
            ;;
        -d|--details)
            include_records=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            show_help
            ;;
    esac
done

# Set default output file if not specified
if [[ -z "$output_file" ]]; then
    output_file="aws-route53-inventory_$(date +%Y%m%d_%H%M%S).csv"
fi

# Verify AWS CLI access
if ! aws sts get-caller-identity &>/dev/null; then
    show_progress "Error: Unable to authenticate with AWS CLI"
    exit 1
fi

show_progress "Starting Route53 inventory..."

if [ "$include_records" = true ]; then
    # Create CSV header with record details
    echo "Zone ID,Zone Name,Private Zone,Record Count,Comment,NS Records,SOA Record,Tags,Record Name,Record Type,Record Value,Record TTL,Routing Policy" > "$output_file"
else
    # Create CSV header without record details
    echo "Zone ID,Zone Name,Private Zone,Record Count,Comment,NS Records,SOA Record,Tags" > "$output_file"
fi

# Get list of hosted zones
show_progress "Fetching Route53 hosted zones..."

aws route53 list-hosted-zones --query 'HostedZones[].[Id,Name,Config.PrivateZone,ResourceRecordSetCount,Config.Comment]' --output text | \
while IFS=$'\t' read -r zone_id zone_name is_private record_count comment; do
    show_progress "Processing zone: $zone_name"
    
    # Clean up zone_id (remove /hostedzone/ prefix)
    zone_id=${zone_id#/hostedzone/}
    
    # Get NS records
    ns_records=$(aws route53 list-resource-record-sets \
        --hosted-zone-id "$zone_id" \
        --query "ResourceRecordSets[?Type=='NS'].[ResourceRecords[].Value]" \
        --output text | tr '\t' ',' || echo "None")
    
    # Get SOA record
    soa_record=$(aws route53 list-resource-record-sets \
        --hosted-zone-id "$zone_id" \
        --query "ResourceRecordSets[?Type=='SOA'].[ResourceRecords[].Value]" \
        --output text | tr '\n' ' ' || echo "None")
    
    # Get tags
    tags=""
    if tag_info=$(aws route53 list-tags-for-resource \
        --resource-type hostedzone \
        --resource-id "$zone_id" \
        --query 'ResourceTagSet.Tags[].[join(`=`,[Key,Value])]' \
        --output text 2>/dev/null); then
        tags=$(echo "$tag_info" | tr '\n' ',' | sed 's/,$//')
    fi
    
    # Handle null values
    comment=${comment:-"N/A"}
    
    if [ "$include_records" = true ]; then
        # Get all records for the zone
        aws route53 list-resource-record-sets --hosted-zone-id "$zone_id" \
            --query 'ResourceRecordSets[].[Name,Type,ResourceRecords[].Value|[0],TTL,TrafficPolicyInstanceId]' \
            --output text | while IFS=$'\t' read -r record_name record_type record_value record_ttl policy_id; do
            
            # Handle aliases and other special records
            if [ -z "$record_value" ]; then
                record_value="See Route53 Console"
            fi
            
            # Handle missing TTL (like for alias records)
            record_ttl=${record_ttl:-"N/A"}
            
            # Determine routing policy
            routing_policy="Simple"
            if [ -n "$policy_id" ]; then
                routing_policy="Traffic Policy"
            fi
            
            # Output to CSV with proper quoting
            printf "%s,%s,%s,%s,\"%s\",\"%s\",\"%s\",\"%s\",%s,%s,\"%s\",%s,%s\n" \
                "$zone_id" \
                "$zone_name" \
                "$is_private" \
                "$record_count" \
                "$comment" \
                "$ns_records" \
                "$soa_record" \
                "$tags" \
                "$record_name" \
                "$record_type" \
                "$record_value" \
                "$record_ttl" \
                "$routing_policy" >> "$output_file"
        done
    else
        # Output zone information only
        printf "%s,%s,%s,%s,\"%s\",\"%s\",\"%s\",\"%s\"\n" \
            "$zone_id" \
            "$zone_name" \
            "$is_private" \
            "$record_count" \
            "$comment" \
            "$ns_records" \
            "$soa_record" \
            "$tags" >> "$output_file"
    fi
done

show_progress "Inventory complete! Output saved to: $output_file" 