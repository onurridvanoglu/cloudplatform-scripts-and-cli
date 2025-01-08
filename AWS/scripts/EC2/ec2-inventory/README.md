# EC2 Scripts

This directory contains scripts for AWS EC2 instance management and inventory.

## Available Scripts

### AWS-EC2-inventory.sh

A comprehensive EC2 instance inventory script that:

- Generates detailed CSV report of EC2 instances in a specified region
- Includes instance details like ID, type, state, IPs, volumes, and tags
- Supports custom output file naming
- Creates both inventory file and execution log

#### Usage

```bash
./AWS-EC2-inventory.sh -r REGION [-o output.csv]
```

#### Options

```bash
-r, --region    AWS region (required)
-o, --output    Output file name (optional)
-h, --help      Show help message
```

#### Example

```bash
./AWS-EC2-inventory.sh -r us-east-1
./AWS-EC2-inventory.sh -r us-west-2 -o my-inventory.csv
```

#### Output Format

See `template.csv` for example output format.

## Future Scripts

This directory may include additional EC2-related scripts such as:

- Instance start/stop automation
- Backup management
- Resource tagging
- Cost optimization tools
