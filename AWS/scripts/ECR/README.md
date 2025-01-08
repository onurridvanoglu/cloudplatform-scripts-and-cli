# ECR Scripts

This directory contains scripts for AWS Elastic Container Registry (ECR) management.

## Available Scripts

### 1. list-ecr-repository.sh

A script to list all ECR repositories that:

- Generates CSV report of ECR repositories
- Includes repository name, URI, and creation date
- Identifies registry/account ID
- Creates execution log

**Usage:**
```
./list-ecr-repository.sh
```

**Output Format:**

The script generates a CSV file with the following columns:
- Repository Name
- Repository URI
- Created Date
- Registry ID (AWS Account ID)

### 2. tag-repository.sh

A script that automatically tags ECR repositories with CostCenter tag:

- Checks and tags all ECR repositories in eu-west-1
- Adds `CostCenter:BT` tag if not present
- Skips repositories that already have the CostCenter tag
- Provides detailed logging and execution summary

**Usage:**
```
./tag-repository.sh
```

**Requirements:**
- AWS CLI installed
- Valid AWS credentials configured
- Required ECR permissions:
  - ecr:ListTagsForResource
  - ecr:TagResource

**Output:**
- Creates timestamped log file with all operations
- Provides summary showing:
  - Total repositories processed
  - Successfully tagged repositories
  - Skipped repositories (already tagged)
  - Failed operations

## Common Requirements

Both scripts require:
- Bash shell
- AWS CLI v2.x or later
- Appropriate AWS IAM permissions
- Active AWS credentials

## Future Scripts

This directory may include additional ECR-related scripts such as:

- Image cleanup automation
- Repository policy management
- Cross-account access setup
- Image vulnerability scanning reports
