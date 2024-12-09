# Route53 Scripts

This directory contains scripts for AWS Route53 DNS management and inventory.

## Available Scripts

### AWS-Route53-inventory.sh
A comprehensive Route53 inventory script that:
- Generates detailed CSV report of all hosted zones
- Optionally includes record details for each zone
- Shows zone configuration and record counts
- Lists NS and SOA records
- Captures all zone tags
- Creates both inventory file and execution log

#### Usage
```bash
./AWS-Route53-inventory.sh [-d] [-o output.csv]
```

#### Options
```
-d, --details    Include record details (optional)
-o, --output     Output file name (optional)
-h, --help       Show help message
```

#### Example
```bash
# Get zones only
./AWS-Route53-inventory.sh

# Get zones and records
./AWS-Route53-inventory.sh -d

# Specify output file
./AWS-Route53-inventory.sh -d -o my-route53-inventory.csv
```

#### Output Format
See `template.csv` for example output format.

## Future Scripts
This directory may include additional Route53-related scripts such as:
- Record management automation
- Health check monitoring
- DNS validation tools
- Zone transfer utilities
- Traffic policy management 