# ECR Scripts

This directory contains scripts for AWS Elastic Container Registry (ECR) management.

## Available Scripts

### list-ecr-repository.sh
A script to list all ECR repositories that:
- Generates CSV report of ECR repositories
- Includes repository name, URI, and creation date
- Identifies registry/account ID
- Creates execution log

#### Usage
```bash
./list-ecr-repository.sh
```

#### Output Format
The script generates a CSV file with the following columns:
- Repository Name
- Repository URI
- Created Date
- Registry ID (AWS Account ID)

## Future Scripts
This directory may include additional ECR-related scripts such as:
- Image cleanup automation
- Repository policy management
- Cross-account access setup
- Image vulnerability scanning reports 