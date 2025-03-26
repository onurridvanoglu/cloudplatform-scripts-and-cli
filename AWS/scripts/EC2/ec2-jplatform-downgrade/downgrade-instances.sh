#!/bin/bash
# =========================================================
# EC2 Jplatform Instance Type Downgrade Tool - Shell Wrapper
# =========================================================
# This shell script is a wrapper for the Python script that downgrades
# jplatform-isbasi EC2 instances from r5a.xlarge/r5a.2xlarge to r5a.large.
# See README.md for detailed usage instructions.

# Set script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PYTHON_SCRIPT="${SCRIPT_DIR}/downgrade_instances.py"

# Display banner
echo "=========================================================="
echo "EC2 Jplatform Instance Type Downgrade Tool"
echo "=========================================================="
echo ""

# Check if Python script exists
if [ ! -f "${PYTHON_SCRIPT}" ]; then
    echo "ERROR: Python script not found at ${PYTHON_SCRIPT}"
    exit 1
fi

# Check if Python is installed
if ! command -v python3 &> /dev/null; then
    echo "ERROR: Python 3 is not installed or not in PATH"
    echo "Please install Python 3.6 or higher"
    exit 1
fi

# Check if boto3 is installed
if ! python3 -c "import boto3" &> /dev/null; then
    echo "WARNING: AWS boto3 library not found"
    echo "Attempting to install boto3..."
    
    if ! pip3 install boto3; then
        echo "ERROR: Failed to install boto3. Please install it manually:"
        echo "pip3 install boto3"
        exit 1
    fi
    
    echo "Successfully installed boto3"
fi

# Check for AWS credentials
if ! python3 -c "import boto3; boto3.Session()" &> /dev/null; then
    echo "WARNING: AWS credentials not found or not properly configured"
    echo "Please set up your AWS credentials using one of these methods:"
    echo "  - Run 'aws configure'"
    echo "  - Set environment variables (AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY)"
    echo "  - Use an AWS profile (--profile option)"
    echo ""
    echo "Continuing anyway, but the script may fail..."
    echo ""
fi

# Display help if requested
if [[ "$*" == *"--help"* ]] || [[ "$*" == *"-h"* ]]; then
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "  --dry-run           Run in dry-run mode without making any changes"
    echo "  --profile PROFILE   AWS profile name to use"
    echo "  --region REGION     AWS region to use (default: eu-west-1)"
    echo "  --parallel NUM      Number of instances to process in parallel (default: 40)"
    echo "  --help, -h          Show this help message and exit"
    echo ""
    echo "Example:"
    echo "  $0 --dry-run --profile prod --region eu-west-1"
    exit 0
fi

# Ask for confirmation unless in dry-run mode
if [[ "$*" != *"--dry-run"* ]]; then
    echo "WARNING: This will downgrade EC2 instances from r5a.xlarge or r5a.2xlarge to r5a.large."
    echo "Instances will be stopped and started during this process."
    echo "It is recommended to run with --dry-run first to see what would be changed."
    echo ""
    read -p "Are you sure you want to continue? (y/N): " -r CONFIRM
    echo ""
    
    if [[ ! $CONFIRM =~ ^[Yy]$ ]]; then
        echo "Operation cancelled."
        exit 0
    fi
fi

# Run the Python script with all arguments passed to this shell script
echo "Running EC2 instance downgrade script..."
echo "Command: python3 ${PYTHON_SCRIPT} $@"
echo ""

python3 "${PYTHON_SCRIPT}" "$@"
RESULT=$?

# Display completion message
echo ""
if [ $RESULT -eq 0 ]; then
    echo "Script completed successfully."
else
    echo "Script completed with errors. Please check the log file for details."
fi

exit $RESULT 