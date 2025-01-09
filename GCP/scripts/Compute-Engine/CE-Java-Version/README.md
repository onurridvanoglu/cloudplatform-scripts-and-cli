# Java Version Check for GCP Compute Engine Instances

This script checks the Java installation status and version across all Compute Engine instances in your GCP project(s) using Identity-Aware Proxy (IAP) tunneling.

## Prerequisites

- Google Cloud SDK (gcloud) installed and configured
- Appropriate IAM permissions:
  - Compute Instance Admin (v1) role or equivalent
  - IAP-secured Tunnel User role
- IAP enabled on the VPC network
- SSH access to the instances through IAP

## Files

- `check_java_version.sh`: Main script that performs the Java version check
- Generated files:
  - `gcp_instance_java-TIMESTAMP.csv`: Output file with Java version information
  - `java_check-TIMESTAMP.log`: Log file with detailed execution information

Where TIMESTAMP format is YYYYMMDD_HHMMSS (e.g., 20240315_143022)

## Usage

1. Make sure you're authenticated with gcloud:
   ```bash
   gcloud auth login
   ```

2. Make the script executable:
   ```bash
   chmod +x check_java_version.sh
   ```

3. Run the script using one of these options:

   a. To check a specific project:
   ```bash
   ./check_java_version.sh -p PROJECT_ID
   ```

   b. To check all accessible projects:
   ```bash
   ./check_java_version.sh
   ```

   c. To display help:
   ```bash
   ./check_java_version.sh -h
   ```

## Output Files

### CSV Output
The script will create a CSV file named `gcp_instance_java-TIMESTAMP.csv` with the following columns:
- Project ID
- Instance Name
- Zone
- Java Status (Installed/Not Installed)
- Java Version

### Log File
A log file named `java_check-TIMESTAMP.log` will be created containing:
- Timestamped execution steps
- Connection attempts
- Success/failure messages
- Error details
- Script completion status

## Error Handling

The script includes basic error handling for:
- Missing gcloud CLI
- Authentication issues
- SSH connection failures
- Invalid project IDs
- Projects without Compute Engine instances
- Invalid command-line arguments
- IAP tunneling issues

## Notes

- The script may take several minutes to complete depending on the number of instances and projects
- Ensure you have proper IAP configuration and permissions
- The script uses IAP tunneling for secure SSH access
- When run without arguments, the script will check all projects you have access to
- Projects without any Compute Engine instances will be skipped
- Make sure IAP is enabled on the VPC networks where your instances reside
- All operations are logged with timestamps for better tracking

## IAP Requirements

To use this script, you need to:
1. Enable Identity-Aware Proxy API in your project
2. Configure the necessary firewall rules
3. Have the "IAP-secured Tunnel User" role
4. Enable IAP for TCP forwarding

For more information on IAP setup, visit:
https://cloud.google.com/iap/docs/using-tcp-forwarding 