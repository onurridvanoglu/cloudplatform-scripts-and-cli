#!/bin/bash

# Enable error handling
set -euo pipefail

# Setup logging
exec 1> >(tee "java_check_$(date +%Y%m%d_%H%M%S).log")
exec 2>&1

# Help function
show_help() {
    echo "Usage: $0 [OPTIONS]"
    echo "Check Java installation on GCP instances"
    echo ""
    echo "Options:"
    echo "  -p, --project PROJECT_ID   Specific project ID (optional)"
    echo "  -o, --output FILE         Output file (default: java_status_TIMESTAMP.csv)"
    exit 1
}

# Initialize variables
project_id=""
output_file="java_status_$(date +%Y%m%d_%H%M%S).csv"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -p|--project)
            project_id="$2"
            shift 2
            ;;
        -o|--output)
            output_file="$2"
            shift 2
            ;;
        -h|--help)
            show_help
            ;;
        *)
            echo "Unknown option: $1"
            show_help
            ;;
    esac
done

# Function to check Java on an instance
check_java() {
    local instance=$1
    local zone=$2
    local project=$3

    echo "Checking Java on $instance..."
    
    # SSH command to check Java
    local java_check=$(gcloud compute ssh "$instance" \
        --project="$project" \
        --zone="$zone" \
        --command="
            if which java >/dev/null 2>&1; then
                echo -n 'Installed,'
                java -version 2>&1 | head -n 1
            else
                echo 'Not installed,NA'
            fi" \
        --quiet \
        --tunnel-through-iap \
        2>/dev/null || echo "Connection failed,NA")

    echo "$java_check"
}

# Create CSV header
echo "Project,Instance,Zone,Status,Java Status,Java Version" > "$output_file"

# Get list of projects
if [[ -z "$project_id" ]]; then
    echo "Getting list of all accessible projects..."
    projects=$(gcloud projects list --format="value(projectId)")
else
    projects="$project_id"
fi

# Process each project
for project in $projects; do
    echo "Processing project: $project"
    
    # Get instances in the project
    echo "Getting instances in $project..."
    instances_json=$(gcloud compute instances list \
        --project="$project" \
        --format="json" \
        2>/dev/null || echo "[]")

    # Process each instance
    echo "$instances_json" | jq -c '.[]' | while read -r instance; do
        name=$(echo "$instance" | jq -r '.name')
        zone=$(echo "$instance" | jq -r '.zone' | awk -F'/' '{print $NF}')
        status=$(echo "$instance" | jq -r '.status')

        echo "Processing instance: $name ($zone) - Status: $status"

        if [[ "$status" != "RUNNING" ]]; then
            echo "$project,$name,$zone,$status,Not checked,NA" >> "$output_file"
            continue
        fi

        # Check Java installation
        IFS=',' read -r java_status java_version < <(check_java "$name" "$zone" "$project")
        echo "$project,$name,$zone,$status,$java_status,\"$java_version\"" >> "$output_file"
    done
done

echo "Java check complete! Results saved to: $output_file" 