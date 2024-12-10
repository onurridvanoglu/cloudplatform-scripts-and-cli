#!/bin/bash

# Add error handling
set -euo pipefail

# Add logging
exec 1> >(tee "storage_inventory_$(date +%Y%m%d_%H%M%S).log")
exec 2>&1

# Function to display help message
show_help() {
    echo "Usage: $0 [OPTIONS]"
    echo "Generate GCP Cloud Storage inventory across projects"
    echo ""
    echo "Options:"
    echo "  -h, --help           Show help message"
    echo "  -o, --output FILE    Specify output file (default: gcp-buckets-all-projects_TIMESTAMP.csv)"
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
    output_file="gcp-buckets-all-projects_$(date +%Y%m%d_%H%M%S).csv"
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
echo "project,bucket_name,location,storage_class,versioning,lifecycle_rules,retention_policy,public_access,labels,creation_time" > "$output_file"

# Process each project
for project in "${projects[@]}"; do
    show_progress "Processing project: $project"
    
    # Validate project access
    if ! gcloud projects describe "$project" >/dev/null 2>&1; then
        show_progress "Error: Project $project not found or not accessible"
        continue
    fi

    # Check if Cloud Storage API is enabled
    if ! gcloud services list --project "$project" --filter="name:storage-api.googleapis.com" --format="get(name)" | grep -q "storage-api.googleapis.com"; then
        show_progress "Warning: Cloud Storage API not enabled in project $project, skipping..."
        continue
    fi

    # Get buckets in the project
    show_progress "Fetching buckets for project: $project"
    
    while IFS=, read -r bucket_name location storage_class versioning lifecycle retention public_access labels creation_time; do
        # Skip if no buckets found or header line
        if [[ -n "$bucket_name" && "$bucket_name" != "name" ]]; then
            # Clean up labels string (remove brackets and quotes)
            labels=$(echo "$labels" | tr -d '[]"' | sed 's/:/=/g')
            
            # Format lifecycle rules count
            if [[ "$lifecycle" == "[]" ]]; then
                lifecycle="0"
            else
                lifecycle=$(echo "$lifecycle" | tr -cd '[' | wc -c)
            fi
            
            # Clean up retention policy (yes/no)
            if [[ "$retention" == "null" ]]; then
                retention="no"
            else
                retention="yes"
            fi
            
            echo "$project,$bucket_name,$location,$storage_class,$versioning,$lifecycle,$retention,$public_access,$labels,$creation_time" >> "$output_file"
        fi
    done < <(gsutil ls -p "$project" -L -b 2>/dev/null | \
        gcloud storage buckets list --project="$project" --format="csv[no-heading](name,location,storageClass,versioning.enabled,lifecycle.rule,retentionPolicy,iamConfiguration.publicAccessPrevention,labels,timeCreated)")
done

show_progress "Storage Inventory complete! Output saved to: $output_file" 