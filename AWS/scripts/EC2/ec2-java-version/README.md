# EC2 Java Version Inventory Script

This script generates a detailed inventory of Java versions installed on EC2 instances. It attempts to connect to instances using both SSH (if key provided) and AWS Systems Manager (SSM) as a fallback.

## Prerequisites

1. AWS CLI installed and configured
2. One of the following:
   - SSH access to instances (private key and appropriate security group rules)
   - AWS Systems Manager (SSM) agent installed on instances
3. Required IAM permissions:
   - ec2:DescribeInstances
   - ssm:SendCommand
   - ssm:GetCommandInvocation

## Usage

Run the script with:

    ./AWS-EC2-java-version.sh -r REGION [-k SSH_KEY] [-u SSH_USER] [-o OUTPUT_FILE]

### Options

- `-h, --help`           Show help message
- `-r, --region`         AWS region (required)
- `-o, --output FILE`    Specify output file (default: ec2-java-versions_TIMESTAMP.csv)
- `-k, --key FILE`       SSH private key file
- `-u, --user USER`      SSH user (default: ec2-user)

### Example

```bash
# Using SSH
./AWS-EC2-java-version.sh -r us-east-1 -k ~/.ssh/my-key.pem -u ec2-user

# Using only SSM
./AWS-EC2-java-version.sh -r us-east-1
```

## Output Fields

The script generates a CSV file with the following columns:

- Instance ID: AWS EC2 instance identifier
- Name: Instance name tag value
- Instance Type: EC2 instance type
- State: Instance state (running, stopped, etc.)
- Private IP: Private IP address
- Public IP: Public IP address (if available)
- Java Version: Detected Java version
- Access Method: How the version was detected (SSH or SSM)

## Access Methods

The script tries two methods to get Java version information:

1. SSH (if key provided):
   - Requires SSH key and public IP access
   - Faster and more reliable
   - Needs appropriate security group rules

2. AWS Systems Manager (SSM):
   - Fallback method if SSH fails or isn't configured
   - Requires SSM agent on instances
   - Works with private instances
   - More permissions required

See template.csv for example output format. 