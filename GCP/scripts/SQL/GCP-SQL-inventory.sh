#!/bin/bash

# Add error handling
set -euo pipefail

# Add logging
exec 1> >(tee "sql_inventory_$(date +%Y%m%d_%H%M%S).log")
exec 2>&1

# Function to display help message
show_help() {
    echo "Usage: $0 [OPTIONS]"
    echo "Generate GCP Cloud SQL instances inventory across projects"
    echo ""
    echo "Options:"
    echo "  -h, --help           Show this help message"
    echo "  -o, --output FILE    Specify output file (default: gcp-sql-instances-all-projects_TIMESTAMP.csv)"
    echo "  -f, --filter FILTER  Filter projects (e.g., 'name:prod-*' or 'labels.env=prod')"
    exit 0
}

# Function to show progress
show_progress() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Parse command line arguments
output_file=""
project_filter=""

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            ;;
        -o|--output)
            output_file="$2"
            shift 2
            ;;
        -f|--filter)
            project_filter="--filter=$2"
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
    output_file="gcp-sql-instances-all-projects_$(date +%Y%m%d_%H%M%S).csv"
fi

# Get list of accessible projects
show_progress "Fetching list of accessible projects..."
readarray -t projects < <(gcloud projects list --format="value(projectId)" $project_filter)

if [[ ${#projects[@]} -eq 0 ]]; then
    show_progress "Error: No accessible projects found"
    exit 1
fi

show_progress "Found ${#projects[@]} accessible projects"

# Create CSV header
echo "project,instance_name,database_version,tier,region,availability_type,storage_size_gb,backup_enabled,private_ip,public_ip,state,creation_time,labels" > "$output_file"

# Process each project
for project in "${projects[@]}"; do
    show_progress "Processing project: $project"
    
    # Validate project access
    if ! gcloud projects describe "$project" >/dev/null 2>&1; then
        show_progress "Error: Project $project not found or not accessible"
        continue
    fi

    # Get SQL instances
    show_progress "Fetching SQL instances for project: $project"
    
    # Check if Cloud SQL API is enabled
    if ! gcloud services list --project "$project" --filter="name:sqladmin.googleapis.com" --format="get(name)" | grep -q "sqladmin.googleapis.com"; then
        show_progress "Warning: Cloud SQL API not enabled in project $project, skipping..."
        continue
    fi

    while IFS=, read -r instance_name database_version tier region availability_type storage_size backup_enabled private_ip public_ip state creation_time labels; do
        # Skip if no instances found
        if [[ -n "$instance_name" && "$instance_name" != "name" ]]; then
            # Clean up labels string (remove brackets and quotes)
            labels=$(echo "$labels" | tr -d '[]"' | sed 's/:/=/g')
            
            echo "$project,$instance_name,$database_version,$tier,$region,$availability_type,$storage_size,$backup_enabled,$private_ip,$public_ip,$state,$creation_time,$labels" >> "$output_file"
        fi
    done < <(gcloud sql instances list --project "$project" \
        --format="csv[no-heading](name,databaseVersion,settings.tier,region,settings.availabilityType,settings.dataDiskSizeGb,settings.backupConfiguration.enabled,ipAddresses[0].ipAddress,ipAddresses[1].ipAddress,state,createTime,settings.userLabels)")
done

show_progress "SQL Inventory complete! Output saved to: $output_file" 