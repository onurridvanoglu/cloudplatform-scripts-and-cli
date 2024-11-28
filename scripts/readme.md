```markdown:AWS_EKS_NodeGroup_Tagging/readme.md
# AWS EKS NodeGroup Resource Tagger

A bash script that automatically tags AWS EKS NodeGroup resources (EC2 instances and EBS volumes) with CostCenter tags for better cost tracking and management.

## Features

- Automatically tags EC2 instances in specified EKS NodeGroup
- Tags all attached EBS volumes
- Includes dry-run mode for safe testing
- Provides detailed logging with timestamps
- Handles errors gracefully
- Validates inputs and AWS CLI availability

## Prerequisites

- AWS CLI installed and configured
- Appropriate AWS IAM permissions:
  - `ec2:DescribeInstances`
  - `ec2:DescribeVolumes`
  - `ec2:CreateTags`

## Usage

```bash
./AWS-NodeGroup-Tag.sh [-n NODEGROUP_NAME] [-t TAG_VALUE] [-d] [-h]

Options:
  -n  NodeGroup name (required)
  -t  CostCenter tag value (required)
  -d  Dry run mode
  -h  Show help message
```

### Examples

Tag resources:
```bash
./AWS-NodeGroup-Tag.sh -n MyNodeGroup -t ProjectA
```

Preview changes with dry run:
```bash
./AWS-NodeGroup-Tag.sh -n MyNodeGroup -t ProjectA -d
```

## Installation

1. Download the script:
```bash
curl -O https://raw.githubusercontent.com/your-repo/AWS-NodeGroup-Tag.sh
```

2. Make it executable:
```bash
chmod +x AWS-NodeGroup-Tag.sh
```

## Sample Output

```
[2024-03-21 10:30:15] Starting tagging process for NodeGroup: MyNodeGroup
[2024-03-21 10:30:16] Fetching instances for NodeGroup
[2024-03-21 10:30:17] Tagging Instance resources: i-1234567890abcdef0
[2024-03-21 10:30:18] Instance resources tagged successfully
[2024-03-21 10:30:19] Tagging Volume resources: vol-1234567890abcdef0
[2024-03-21 10:30:20] Volume resources tagged successfully
[2024-03-21 10:30:21] Tagging process completed successfully
```

## Error Handling

The script will exit with an error message if:
- Required parameters are missing
- AWS CLI is not installed
- No instances are found in the specified NodeGroup
- Tagging operations fail
- AWS credentials are invalid or expired

## Security Notes

- Use appropriate IAM roles with least privilege
- Review changes in dry-run mode before actual execution
- Keep AWS credentials secure and regularly rotated

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

MIT License

## Support

For issues and feature requests, please create an issue in the repository.
```

This README provides essential information for users to understand and use the script effectively. The format is concise yet informative, focusing on practical usage while including important security and prerequisite information.