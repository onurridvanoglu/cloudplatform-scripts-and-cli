# RDS Scripts

This directory contains scripts for AWS RDS instance management and inventory.

## Available Scripts

### AWS-RDS-inventory.sh

A comprehensive RDS instance inventory script that:

- Generates detailed CSV report of RDS instances in a specified region
- Includes instance details like ID, class, engine, storage, and configuration
- Captures backup retention periods and Multi-AZ status
- Includes endpoint information and port numbers
- Supports custom output file naming
- Creates both inventory file and execution log

#### Usage

```bash
./AWS-RDS-inventory.sh -r REGION [-o output.csv]
```

#### Options

```bash
-r, --region    AWS region (required)
-o, --output    Output file name (optional)
-h, --help      Show help message
```

#### Example

```bash
./AWS-RDS-inventory.sh -r us-east-1
./AWS-RDS-inventory.sh -r us-west-2 -o my-rds-inventory.csv
```

#### Output Format

See `template.csv` for example output format.

## Future Scripts

This directory may include additional RDS-related scripts such as:

- Backup management
- Performance monitoring
- Configuration management
- Cross-region replication setup
- Security group management
