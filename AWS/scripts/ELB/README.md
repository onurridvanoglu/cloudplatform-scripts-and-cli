# ELB Scripts

This directory contains scripts for AWS Elastic Load Balancer management and inventory.

## Available Scripts

### AWS-ELB-inventory.sh
A comprehensive ELB inventory script that:
- Generates detailed CSV report of all Load Balancers (ALB and NLB) in a specified region
- Includes configuration details like type, scheme, and state
- Lists associated security groups (for ALBs)
- Shows listener configurations and target groups
- Captures availability zone distribution
- Includes all resource tags
- Creates both inventory file and execution log

#### Usage
```bash
./AWS-ELB-inventory.sh -r REGION [-o output.csv]
```

#### Options
```
-r, --region    AWS region (required)
-o, --output    Output file name (optional)
-h, --help      Show help message
```

#### Example
```bash
./AWS-ELB-inventory.sh -r us-east-1
./AWS-ELB-inventory.sh -r us-west-2 -o my-elb-inventory.csv
```

#### Output Format
See `template.csv` for example output format.

## Future Scripts
This directory may include additional ELB-related scripts such as:
- Target group health monitoring
- SSL certificate management
- Access log analysis
- Security group management
- Load balancer metrics collection 