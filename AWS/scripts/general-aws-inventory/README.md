# AWS Inventory Scripts

This directory contains scripts for gathering inventory information from various AWS services.

## Main Script

### AWS-inventory-all.sh

This script runs all individual service inventory scripts and collects their outputs in a single directory.

#### Usage

```bash
./AWS-inventory-all.sh -r REGION [-o output_directory]
```

#### Options

- `-h, --help`           Show help message
- `-r, --region`         AWS region (required)
- `-o, --output-dir`     Output directory (default: aws-inventory_TIMESTAMP)

#### Example

```bash
./AWS-inventory-all.sh -r us-east-1 -o my-inventory
```

This will create a directory 'my-inventory' containing:
- ec2-inventory.csv
- rds-inventory.csv
- s3-inventory.csv
- elb-inventory.csv
- route53-inventory.csv
- aws_inventory_all_TIMESTAMP.log

#### Prerequisites

1. AWS CLI installed and configured
2. Appropriate IAM permissions for all services:
   - EC2: ec2:Describe*
   - RDS: rds:Describe*
   - S3: s3:List*, s3:GetBucket*
   - ELB: elasticloadbalancing:Describe*
   - Route53: route53:List*, route53:Get*

## Template Files

The `templates` directory contains example CSV files showing the expected format for each service's inventory:

1. ec2-template.csv - EC2 instance inventory format
2. rds-template.csv - RDS instance inventory format
3. s3-template.csv - S3 bucket inventory format
4. elb-template.csv - Load balancer inventory format
5. route53-template.csv - Route53 hosted zones inventory format 