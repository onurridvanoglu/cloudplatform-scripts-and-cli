#!/bin/bash

# Add error handling
set -euo pipefail

# Add logging
exec 1> >(tee "ec2_java_version_$(date +%Y%m%d_%H%M%S).log")
exec 2>&1

# Function to display help message
show_help() {
    echo "Usage: $0 [OPTIONS]"
    echo "Generate inventory of Java versions installed on EC2 instances"
    echo ""
    echo "Options:"
    echo "  -h, --help           Show help message"
    echo "  -r, --region         AWS region (required)"
    echo "  -o, --output FILE    Specify output file (default: ec2-java-versions_TIMESTAMP.csv)"
    echo "  -k, --key FILE       SSH private key file"
    echo "  -u, --user USER      SSH user (default: ec2-user)"
    exit 0
}

# Function to show progress
show_progress() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Parse command line arguments
output_file=""
region="eu-west-1"
ssh_key=""
ssh_user="ec2-user"

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
        -k|--key)
            ssh_key="$2"
            shift 2
            ;;
        -u|--user)
            ssh_user="$2"
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
    output_file="ec2-java-versions_$(date +%Y%m%d_%H%M%S).csv"
fi

# Verify AWS CLI access
if ! aws sts get-caller-identity &>/dev/null; then
    show_progress "Error: Unable to authenticate with AWS CLI"
    exit 1
fi

# Function to check Java version via SSH
check_java_via_ssh() {
    local ip=$1
    local java_info=""
    
    if [[ -n "$ssh_key" ]]; then
        java_info=$(ssh -i "$ssh_key" -o StrictHostKeyChecking=no -o ConnectTimeout=5 "${ssh_user}@${ip}" '
            # Check if Java exists
            if ! sudo which java >/dev/null 2>&1; then
                echo "Java not installed"
                exit 0
            fi

            # Get Java version and vendor info
            version=$(sudo java -version 2>&1 | head -n 1)
            vendor=$(sudo java -XshowSettings:properties -version 2>&1 | grep "java.specification.vendor" || echo "Vendor not found")
            
            echo "$version|$vendor"
        ' 2>/dev/null || echo "SSH Failed")
    fi
    echo "$java_info"
}

# Function to check Java version via SSM
check_java_via_ssm() {
    local instance_id=$1
    local java_info=""
    
    # Script to check Java version and vendor
    local ssm_script='#!/bin/bash
# Check if Java exists
if ! which java >/dev/null 2>&1; then
    echo "Java not installed"
    exit 0
fi

# Get Java version and vendor info
version=$(java -version 2>&1 | head -n 1)
vendor=$(java -XshowSettings:properties -version 2>&1 | grep "java.specification.vendor" || echo "Vendor not found")
echo "$version|$vendor"'
    
    # Send command through SSM using proper format
    local command_id=$(aws ssm send-command \
        --region "$region" \
        --targets "[{\"Key\":\"InstanceIds\",\"Values\":[\"$instance_id\"]}]" \
        --document-name "AWS-RunShellScript" \
        --parameters "{\"commands\":[\"$ssm_script\"],\"executionTimeout\":[\"3600\"]}" \
        --timeout-seconds 600 \
        --max-concurrency "1" \
        --max-errors "0" \
        --output text \
        --query "Command.CommandId" 2>/dev/null)
    
    if [[ -n "$command_id" ]]; then
        # Wait longer for command completion
        sleep 10
        
        # Check command status first
        local status=$(aws ssm get-command-invocation \
            --region "$region" \
            --command-id "$command_id" \
            --instance-id "$instance_id" \
            --query "Status" \
            --output text 2>/dev/null || echo "Failed")
            
        show_progress "Command status for $instance_id: $status"
        
        if [[ "$status" == "Success" ]]; then
            java_info=$(aws ssm get-command-invocation \
                --region "$region" \
                --command-id "$command_id" \
                --instance-id "$instance_id" \
                --query "StandardOutput" \
                --output text 2>/dev/null || echo "SSM Failed")
        else
            java_info="SSM Failed: $status"
        fi
        
        # Debug output
        show_progress "SSM output for $instance_id: $java_info"
    else
        show_progress "Failed to send SSM command to $instance_id"
        java_info="SSM Failed: Could not send command"
    fi
    
    echo "$java_info"
}

show_progress "Starting EC2 Java version inventory for region: $region"

# Create CSV header
echo "Instance ID,Name,Instance Type,State,Private IP,Public IP,Java Version,Java Vendor,Access Method" > "$output_file"

# Get EC2 instances
show_progress "Fetching EC2 instances..."
instances=$(aws ec2 describe-instances \
    --region "$region" \
    --query 'Reservations[].Instances[].[InstanceId,Tags[?Key==`Name`].Value|[0],InstanceType,State.Name,PrivateIpAddress,PublicIpAddress]' \
    --output text)

# Process each instance
while IFS=$'\t' read -r instance_id name type state private_ip public_ip; do
    show_progress "Processing instance: $instance_id"
    
    # Clean up instance data (removed tr -d '"' since we're using text output)
    name=${name:-""}
    type=${type:-""}
    state=${state:-""}
    private_ip=${private_ip:-""}
    public_ip=${public_ip:-""}
    
    java_info=""
    access_method=""
    
    # Try SSH first if key is provided and instance has public IP
    if [[ -n "$ssh_key" && -n "$public_ip" && "$public_ip" != "null" ]]; then
        java_info=$(check_java_via_ssh "$public_ip")
        if [[ "$java_info" != "SSH Failed" ]]; then
            access_method="SSH"
        fi
    fi
    
    # Try SSM if SSH failed or wasn't attempted
    if [[ -z "$java_info" || "$java_info" == "SSH Failed" ]]; then
        java_info=$(check_java_via_ssm "$instance_id")
        if [[ "$java_info" != "SSM Failed" ]]; then
            access_method="SSM"
        fi
    fi
    
    # Parse Java info
    java_version=$(echo "$java_info" | cut -d'|' -f1 | tr -d '"' | tr ',' ' ')
    java_vendor=$(echo "$java_info" | cut -d'|' -f2 | tr -d '"' | tr ',' ' ')
    
    # Write to CSV
    echo "$instance_id,$name,$type,$state,$private_ip,$public_ip,\"$java_version\",\"$java_vendor\",$access_method" >> "$output_file"
done <<< "$instances"

show_progress "Java version inventory complete! Output saved to: $output_file" 