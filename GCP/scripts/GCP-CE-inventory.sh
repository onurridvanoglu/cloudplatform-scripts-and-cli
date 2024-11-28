#!/bin/bash

# Add error handling
set -euo pipefail

# Add logging
exec 1> >(tee "inventory_$(date +%Y%m%d_%H%M%S).log")
exec 2>&1

# Function to display help message
show_help() {
    echo "Usage: $0 [OPTIONS]"
    echo "Generate GCP Compute Engine inventory across projects"
    echo ""
    echo "Options:"
    echo "  -h, --help           Show this help message"
    echo "  -o, --output FILE    Specify output file (default: gcp-instances-all-projects_TIMESTAMP.csv)"
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
    output_file="gcp-instances-all-projects_$(date +%Y%m%d_%H%M%S).csv"
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
echo "project,name,zone,machine_type,vcpu,memory_gb,status,network_ip,external_ip,disk_name,disk_size_gb,creation_timestamp,tags,labels" > "$output_file"

# Initialize machine type cache
declare -A machine_type_cache

# Process each project
for project in "${projects[@]}"; do
    show_progress "Processing project: $project"
    
    # Validate project access
    if ! gcloud projects describe "$project" >/dev/null 2>&1; then
        show_progress "Error: Project $project not found or not accessible"
        continue
    fi

    # Get instances and their zones
    show_progress "Fetching instances for project: $project"
    
    while IFS=, read -r instance zone machine_type rest; do
        # Skip header line
        if [[ $instance != "name" ]]; then
            # Extract zone from full zone path
            zone=$(echo "$zone" | cut -d'/' -f9)
            
            # Use cached machine details if available
            cache_key="${project}_${zone}_${machine_type}"
            if [[ -z "${machine_type_cache[$cache_key]:-}" ]]; then
                show_progress "Fetching machine type details for: $machine_type in $zone"
                machine_type_cache[$cache_key]=$(gcloud compute machine-types describe "$machine_type" \
                    --zone "$zone" \
                    --project "$project" \
                    --format="csv[no-heading](guestCpus,memoryMb)")
            fi
            
            machine_details="${machine_type_cache[$cache_key]}"
            vcpu=$(echo "$machine_details" | cut -d',' -f1)
            memory_mb=$(echo "$machine_details" | cut -d',' -f2)
            memory_gb=$(awk -v mem="$memory_mb" 'BEGIN {printf "%.1f", mem/1024}')

            # Output all details
            echo "$project,$instance,$zone,$machine_type,$vcpu,$memory_gb,$rest" >> "$output_file"
        fi
    done < <(gcloud compute instances list --project "$project" \
        --format="csv(name,zone,machine_type.basename(),status,networkInterfaces[0].networkIP,networkInterfaces[0].accessConfigs[0].natIP,disks.deviceName,disks[0].diskSizeGb,creationTimestamp,tags.items,labels)")
done

show_progress "Inventory complete! Output saved to: $output_file"