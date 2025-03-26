# EC2 Jplatform Instance Type Downgrade Tool

A Python script to systematically downgrade Amazon EC2 instances with tag `Category=Jplatform` from `r5a.xlarge` or `r5a.2xlarge` to `r5a.large`.

## Overview

This tool identifies EC2 instances that:
1. Have the tag `Category=Jplatform`
2. Have names matching the pattern `jplatform-isbasi-XX` where XX is a number between 61 and 134
3. Are currently of instance type `r5a.xlarge` or `r5a.2xlarge`

It then performs the following operations:
1. Stops each instance (if running)
2. Modifies the instance type to `r5a.large`
3. Starts the instance (if it was running before)

The script includes safety features such as:
- Dry run mode to preview changes without making them
- Skipping instances that are already `r5a.large`
- Explicitly excluding `jplatform-isbasi-135`
- Parallel processing with configurable concurrency
- Detailed logging

## Prerequisites

- Python 3.6 or higher
- AWS SDK for Python (boto3)
- AWS credentials configured with permissions to:
  - Describe EC2 instances
  - Stop and start EC2 instances
  - Modify EC2 instance attributes

## Installation

1. Ensure you have Python 3.6+ installed:
   ```bash
   python --version
   ```

2. Install required dependencies:
   ```bash
   pip install boto3
   ```

3. Configure AWS credentials:
   - Using AWS CLI: `aws configure`
   - Or by setting environment variables:
     ```bash
     export AWS_ACCESS_KEY_ID="your-access-key"
     export AWS_SECRET_ACCESS_KEY="your-secret-key"
     export AWS_DEFAULT_REGION="eu-west-1"
     ```
   - Or using an AWS profile in `~/.aws/credentials`

## Usage

### Basic Usage

```bash
python downgrade_instances.py
```

### With Options

```bash
# Dry run mode (no actual changes)
python downgrade_instances.py --dry-run

# Specify AWS profile
python downgrade_instances.py --profile prod-admin

# Specify AWS region
python downgrade_instances.py --region eu-central-1

# Control parallel execution
python downgrade_instances.py --parallel 10

# Combine options
python downgrade_instances.py --dry-run --profile prod-admin --region eu-west-1 --parallel 3
```

## Command Line Options

| Option | Description | Default |
|--------|-------------|---------|
| `--dry-run` | Run in dry-run mode without making any changes | False |
| `--profile` | AWS profile name to use | Default profile |
| `--region` | AWS region to use | eu-west-1 |
| `--parallel` | Number of instances to process in parallel | 40 |
| `--help` | Show help message and exit | |

## Example Output

```
2023-02-26 10:15:32 - INFO - Running in DRY RUN mode - no changes will be made
2023-02-26 10:15:33 - INFO - Found 73 instances with tag Category=Jplatform
2023-02-26 10:15:33 - INFO - Filtered to 45 target instances in the range jplatform-isbasi-61 to jplatform-isbasi-134
2023-02-26 10:15:33 - INFO - Instance jplatform-isbasi-61 (i-0123456789abcdef0) is r5a.large, skipping
2023-02-26 10:15:33 - INFO - Instance jplatform-isbasi-62 (i-abcdef0123456789a) is r5a.xlarge, will be downgraded to r5a.large
...
2023-02-26 10:15:34 - INFO - Found 20 instances that need downgrading
2023-02-26 10:15:34 - INFO - Starting downgrade process for jplatform-isbasi-62 (i-abcdef0123456789a)
2023-02-26 10:15:34 - INFO - DRY RUN: Would stop instance jplatform-isbasi-62 (i-abcdef0123456789a)
2023-02-26 10:15:34 - INFO - DRY RUN: Would modify jplatform-isbasi-62 (i-abcdef0123456789a) from r5a.xlarge to r5a.large
2023-02-26 10:15:34 - INFO - DRY RUN: Would start instance jplatform-isbasi-62 (i-abcdef0123456789a)
...

=================================================
SUMMARY
=================================================
Total instances processed: 45
Instances downgraded: 20
Instances skipped: 25
Instances failed: 0
=================================================
```

## Logging

The script logs all actions to both console and a file named `ec2_downgrade.log` in the same directory as the script. The log includes:

- Instances discovered with the tag
- Instances filtered by name pattern
- Status of each instance (needs downgrade or skipped)
- Details of stop, modify, and start operations
- Summary of operations performed

## Error Handling

The script includes robust error handling:

- If AWS credentials are invalid or missing, the script will exit with an error message
- If an instance fails to stop, modify, or start, it will be marked as failed in the summary
- The script will continue processing other instances even if some fail
- A non-zero exit code is returned if any instance fails to be processed

## Safety Considerations

1. **Always run with `--dry-run` first** to verify which instances will be affected.
2. The script will skip instances that are already `r5a.large`.
3. Make sure you have the necessary permissions before running the script.
4. Be aware that stopping and starting instances will result in:
   - Brief service interruption
   - New public IP addresses for instances that don't have Elastic IPs
   - Potential data loss for ephemeral storage
5. Consider running during a maintenance window to minimize impact.

## Troubleshooting

If you encounter issues:

1. Check the log file for detailed error messages
2. Verify your AWS credentials have sufficient permissions
3. Ensure the instances you're targeting exist and match the filtering criteria
4. Check if any instances are in a state that doesn't allow modification (e.g., pending)

## License

This script is provided under the MIT License. Use at your own risk. 