# AWS Scripts Documentation

This directory contains scripts for gathering inventory information from various AWS services.

## Available Scripts

### Service-Specific Inventory Scripts

1. [EC2](EC2/README.md)
   - `AWS-EC2-inventory.sh` - Inventory of EC2 instances
   - Includes instance details, types, states, IPs, and tags

2. [RDS](RDS/README.md)
   - `AWS-RDS-inventory.sh` - Inventory of RDS instances
   - Includes database instances, types, versions, and configurations

3. [S3](S3/README.md)
   - `AWS-S3-inventory.sh` - Inventory of S3 buckets
   - Includes bucket details, versioning, encryption settings

4. [ELB](ELB/README.md)
   - `AWS-ELB-inventory.sh` - Inventory of Elastic Load Balancers
   - Includes load balancer configurations, listeners, and target groups

5. [Route53](Route53/README.md)
   - `AWS-Route53-inventory.sh` - Inventory of Route53 hosted zones
   - Includes DNS zones, records, and configurations

### Comprehensive Inventory Script

The [general-aws-inventory](general-aws-inventory/README.md) directory contains:
- `AWS-inventory-all.sh` - Runs all individual inventory scripts
- Template files showing expected output formats
- Comprehensive documentation

## Prerequisites

1. AWS CLI installed and configured
2. Appropriate IAM permissions for services being inventoried
3. Bash shell environment

## Usage

Each script can be run individually from its respective directory, or you can use the comprehensive inventory script:

```bash
# Individual service inventory
./EC2/AWS-EC2-inventory.sh -r REGION [-o output.csv]
./RDS/AWS-RDS-inventory.sh -r REGION [-o output.csv]
./S3/AWS-S3-inventory.sh [-o output.csv]
./ELB/AWS-ELB-inventory.sh -r REGION [-o output.csv]
./Route53/AWS-Route53-inventory.sh [-o output.csv]

# Comprehensive inventory
./general-aws-inventory/AWS-inventory-all.sh -r REGION [-o output_directory]
```

## Output Format

Each script generates:
1. CSV file with inventory data
2. Log file with execution details

See individual script documentation and templates for specific output formats. 