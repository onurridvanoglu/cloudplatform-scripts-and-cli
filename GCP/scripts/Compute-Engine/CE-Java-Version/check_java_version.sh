#!/bin/bash

# Set timestamp format
TIMESTAMP=$(date '+%Y%m%d_%H%M%S')

# Set script variables
OUTPUT_FILE="gcp_instance_java-${TIMESTAMP}.csv"
LOG_FILE="java_check-${TIMESTAMP}.log"

# Function to log messages with timestamp
log_message() {
    local message=$1
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[${timestamp}] ${message}" | tee -a "$LOG_FILE"
}

# Function to display usage
usage() {
    echo "Usage: $0 [-p PROJECT_ID] [-h]"
    echo "  -p PROJECT_ID    Specify a GCP project ID to check"
    echo "  -h              Display this help message"
    echo
    echo "If no project is specified, script will check all accessible projects"
    exit 1
}

# Function to check Java version on an instance
check_java() {
    local project=$1
    local instance=$2
    local zone=$3

    log_message "Attempting to connect to instance $instance in zone $zone" >&2

    # Use the exact command that works
    local java_output
    java_output=$(gcloud compute ssh "$instance" \
        --project="$project" \
        --zone="$zone" \
        --tunnel-through-iap \
        --command="java -version 2>&1 || echo 'Java not installed'" \
        2>/dev/null)

    if [ $? -eq 0 ]; then
        log_message "Successfully connected to instance $instance" >&2
        if [[ $java_output == *"version"* ]]; then
            # Extract version number
            local version
            version=$(echo "$java_output" | grep "version" | awk '{print $3}' | tr -d '"')
            log_message "Found Java version $version on instance $instance" >&2
            echo "Installed,$version"
        elif [[ $java_output == *"Java not installed"* ]]; then
            log_message "Java not installed on instance $instance" >&2
            echo "Not Installed,N/A"
        else
            log_message "Unable to determine Java status on instance $instance" >&2
            echo "Unknown,N/A"
        fi
    else
        log_message "Failed to connect to instance $instance" >&2
        echo "Connection Failed,N/A"
    fi
}

# Function to check Java versions for a specific project
check_project() {
    local project=$1
    log_message "Starting check for project: $project"
    
    # Set the current project
    log_message "Setting current project to $project"
    gcloud config set project "$project" --quiet >/dev/null

    # Get list of all instances in the project
    log_message "Fetching list of instances in project $project"
    local instance_list
    mapfile -t instance_list < <(gcloud compute instances list \
        --project="$project" \
        --format="csv[no-heading](name,zone)" \
        --filter="status=RUNNING" 2>/dev/null)
    
    if [ ${#instance_list[@]} -eq 0 ]; then
        log_message "No instances found in project $project"
        return
    fi

    log_message "Found ${#instance_list[@]} instances in project $project"

    # Debug: Print all instances
    for instance_info in "${instance_list[@]}"; do
        local name zone
        IFS=, read -r name zone <<< "$instance_info"
        log_message "Found instance: $name in zone: $zone"
    done

    # Process each instance
    for instance_info in "${instance_list[@]}"; do
        local instance_name zone status version
        IFS=, read -r instance_name zone <<< "$instance_info"
        log_message "Processing instance: $instance_name in zone: $zone"
        
        # Get Java status and version
        local java_check_output
        java_check_output=$(check_java "$project" "$instance_name" "$zone")
        IFS=, read -r status version <<< "$java_check_output"
        
        # Append to CSV file
        printf "%s,%s,%s,%s,%s\n" \
            "$project" \
            "$instance_name" \
            "$zone" \
            "${status:-Connection Failed}" \
            "${version:-N/A}" >> "$OUTPUT_FILE"
        
        # Add a small delay between instances
        sleep 2
    done
    
    log_message "Completed checking project: $project"
}

# Function to check all projects
check_all_projects() {
    log_message "No project specified, checking all accessible projects"
    projects=$(gcloud projects list --format="value(projectId)")
    
    if [ -z "$projects" ]; then
        log_message "Error: No accessible projects found"
        exit 1
    fi
    
    while read -r project; do
        check_project "$project"
    done <<< "$projects"
}

# Initialize log file
log_message "Starting Java version check script"

# Check if gcloud is installed
if ! command -v gcloud &> /dev/null; then
    log_message "Error: gcloud CLI is not installed"
    exit 1
fi

# Check if user is authenticated
if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" &> /dev/null; then
    log_message "Error: Not authenticated with gcloud. Please run 'gcloud auth login'"
    exit 1
fi

# Parse command line arguments
while getopts ":p:h" opt; do
    case ${opt} in
        p )
            PROJECT_ID=$OPTARG
            ;;
        h )
            usage
            ;;
        \? )
            log_message "Invalid Option: -$OPTARG"
            usage
            ;;
        : )
            log_message "Invalid Option: -$OPTARG requires an argument"
            usage
            ;;
    esac
done

# Create new output file with headers
log_message "Creating output file: $OUTPUT_FILE"
{
    echo "Project ID,Instance Name,Zone,Java Status,Java Version"
} > "$OUTPUT_FILE"

# Execute based on arguments
if [ -n "$PROJECT_ID" ]; then
    # Verify project exists and is accessible
    if ! gcloud projects describe "$PROJECT_ID" &>/dev/null; then
        log_message "Error: Project $PROJECT_ID not found or not accessible"
        exit 1
    fi
    check_project "$PROJECT_ID"
else
    check_all_projects
fi

log_message "Java version check completed. Results saved to $OUTPUT_FILE"
log_message "Log file saved as $LOG_FILE" 