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

## Individual Service Scripts

The following service-specific inventory scripts are available:

1. [EC2](EC2/README.md) - EC2 instance inventory
2. [RDS](RDS/README.md) - RDS instance inventory
3. [S3](S3/README.md) - S3 bucket inventory
4. [ELB](ELB/README.md) - Load balancer inventory
5. [Route53](Route53/README.md) - Route53 hosted zones inventory

Each script can be run individually. See their respective README files for details. 