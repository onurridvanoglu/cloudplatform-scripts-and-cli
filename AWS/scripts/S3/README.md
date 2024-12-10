# S3 Scripts

This directory contains scripts for AWS S3 bucket management and inventory.

## Available Scripts

### AWS-S3-inventory.sh

A comprehensive S3 bucket inventory script that:

- Generates detailed CSV report of all S3 buckets
- Includes bucket details like creation date, region, versioning status
- Tracks encryption and public access settings
- Captures all bucket tags
- Supports custom output file naming
- Creates both inventory file and execution log

#### Usage

```bash
./AWS-S3-inventory.sh [-o output.csv]
```

#### Options

```bash
-o, --output    Output file name (optional)
-h, --help      Show help message
```

#### Example

```bash
./AWS-S3-inventory.sh
./AWS-S3-inventory.sh -o my-s3-inventory.csv
```

#### Output Format

See `template.csv` for example output format.

## Future Scripts

This directory may include additional S3-related scripts such as:

- Bucket lifecycle management
- Access policy auditing
- Storage class optimization
- Cross-region replication setup
