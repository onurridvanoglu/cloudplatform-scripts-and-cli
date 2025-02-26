# Docker Container Restart Lambda Function

This Lambda function automatically restarts Docker containers named 'jplatform' running on EC2 instances on a scheduled basis. The function processes instances sequentially with a 5-second delay between each instance to ensure controlled rollout.

## Prerequisites

1. EC2 instances must have:
   - AWS Systems Manager Agent (SSM Agent) installed
   - Docker installed and running
   - An IAM role that allows Systems Manager access
   - A Docker container named 'jplatform' running

2. The Lambda function requires an IAM role with the following permissions:
   - AWSLambdaBasicExecutionRole
   - EC2 Read permissions
   - Systems Manager SendCommand permissions

## Configuration Options

The function requires one of the following environment variable configurations (mandatory):

1. **Specific Instance IDs**:
   - Set `TARGET_INSTANCE_IDS` environment variable
   - Format: Comma-separated list of instance IDs
   - Example: `i-1234567890abcdef0,i-0987654321fedcba0`
   - Note: Instances will be processed in the order specified in this list

2. **Instance Tags**:
   - Set BOTH `TARGET_TAG_KEY` and `TARGET_TAG_VALUE` environment variables
   - Example: 
     - `TARGET_TAG_KEY`: `Environment`
     - `TARGET_TAG_VALUE`: `Production`

**Important**: The function will fail if neither of these configurations is provided. This is a safety measure to prevent accidental processing of all instances.

## Processing Behavior

The function processes instances with the following behavior:
1. Instances are processed one at a time
2. First instance is processed immediately
3. A 5-second delay is added before processing each subsequent instance
4. Each instance's jplatform container is restarted using Docker's restart command
5. Detailed logs are generated for each step in CloudWatch

## Setup Instructions

1. Create an IAM Role for Lambda:
   - Go to IAM Console
   - Create a new role for Lambda
   - Attach the following policies:
     ```json
     {
         "Version": "2012-10-17",
         "Statement": [
             {
                 "Effect": "Allow",
                 "Action": [
                     "ec2:DescribeInstances",
                     "ssm:SendCommand",
                     "ssm:GetCommandInvocation",
                     "logs:CreateLogGroup",
                     "logs:CreateLogStream",
                     "logs:PutLogEvents"
                 ],
                 "Resource": "*"
             }
         ]
     }
     ```

2. Create the Lambda Function:
   - Create a new Python Lambda function
   - Upload the `restart_containers.py` script
   - Set the timeout to 5 minutes
   - Assign the IAM role created in step 1

3. Create EventBridge (CloudWatch Events) Rule:
   - Create a new rule
   - Set the schedule expression to: `cron(0 3 * * ? *)`
   - Set the target as your Lambda function

## Lambda Environment Variables Setup

1. In the Lambda console, go to the Configuration tab
2. Select "Environment variables"
3. Add one of the following configurations:

   a. For specific instances:
   ```
   TARGET_INSTANCE_IDS = i-1234567890abcdef0,i-0987654321fedcba0
   ```
   Note: The order of instance IDs matters as they will be processed sequentially.

   b. For instances with specific tags:
   ```
   TARGET_TAG_KEY = Environment
   TARGET_TAG_VALUE = Production
   ```

## Testing

You can test the function by:
1. Going to the Lambda console
2. Creating a test event (empty JSON object `{}` is sufficient)
3. Clicking the "Test" button
4. Monitoring CloudWatch logs to observe:
   - Sequential processing of instances
   - 5-second delays between instances
   - Success/failure of container restarts

## Monitoring

The function logs to CloudWatch Logs. You can monitor:
- Function execution status
- Number of instances processed successfully and failed
- Container restart status for each instance
- Timing of instance processing including delays
- Command IDs for each successful SSM command execution
- Detailed error messages for failed instances
- **Actual command output from each instance including:**
  - Command execution status
  - Standard output
  - Standard error (if any)

Example log output:
```
Processing instance: i-1234567890abcdef0
Initiated jplatform container restart on instance i-1234567890abcdef0 with command ID: 12345
Command output for instance i-1234567890abcdef0:
Status: Success
Output:
Restarting jplatform container: abc123def456
Successfully restarted jplatform container

Waiting 5 seconds before processing next instance...
Processing instance: i-0987654321fedcba0
Initiated jplatform container restart on instance i-0987654321fedcba0 with command ID: 67890
Command output for instance i-0987654321fedcba0:
Status: Failed
Error: No jplatform container found running

Processing complete. Successfully processed 1 instances, Failed to process 1 instances
Failed instances:
Instance i-0987654321fedcba0: Command failed with status Failed: No jplatform container found running
```

## Error Handling

The script implements robust error handling:
1. Each instance is processed independently
2. If sending a command to one instance fails:
   - The error is logged
   - The instance is marked as failed
   - The script continues processing remaining instances
   - A summary of failures is provided at the end
3. For each command execution:
   - The script waits briefly for the command to complete
   - Fetches and logs the actual command output
   - Checks the command status
   - Records both successful and failed executions
4. The function returns a detailed results object containing:
   - List of successfully processed instances with their command IDs and outputs
   - List of failed instances with their error messages

Example response:
```json
{
    "statusCode": 200,
    "body": {
        "message": "Container restart initiated successfully",
        "results": {
            "successful": [
                {
                    "instance_id": "i-1234567890abcdef0",
                    "command_id": "12345",
                    "status": "Success",
                    "output": "Restarting jplatform container: abc123def456\nSuccessfully restarted jplatform container"
                }
            ],
            "failed": [
                {
                    "instance_id": "i-0987654321fedcba0",
                    "error": "Command failed with status Failed: No jplatform container found running"
                }
            ]
        },
        "timestamp": "2024-01-01T03:00:00.000Z"
    }
}
```

## Customization

To modify which containers are restarted, edit the shell command in the `restart_containers()` function. The current script restarts all running containers, but you can add filters based on container names, labels, or other criteria.

## Troubleshooting

Common issues:
1. SSM Agent not running on EC2 instances
2. Insufficient IAM permissions
3. Docker service not running on instances
4. Network connectivity issues
5. Container named 'jplatform' not found on instance
6. Lambda timeout (if processing many instances)

Check CloudWatch Logs for detailed error messages and execution status. Each instance processing step and delay is logged for easy troubleshooting.

## Container State Logging

The script logs container state information to `/var/log/container_stats.log` on each instance before performing a restart. Each log entry contains:

1. **Timestamp** of the restart event
2. **Container Status** (`docker ps -a` output)
3. **Resource Usage** (`docker stats --no-stream` output)

Example log file content:
```
=== Container Restart Event: 2024-01-01 03:00:00 ===
Current Container Status:
CONTAINER ID   IMAGE                COMMAND    STATUS          NAMES
abc123def456   jplatform:latest    "..."      Up 2 days       jplatform

Container Stats:
CONTAINER ID   NAME        CPU %     MEM USAGE / LIMIT     MEM %     NET I/O           BLOCK I/O
abc123def456   jplatform   0.15%     1.2GiB / 16GiB        7.50%     12MB / 34MB      156MB / 23MB
```

The log file:
- Appends new entries for each restart operation
- Maintains historical container state data
- Provides point-in-time snapshots of container status and resource usage

## Error Handling

The script implements robust error handling:
1. Each instance is processed independently
2. If sending a command to one instance fails:
   - The error is logged
   - The instance is marked as failed
   - The script continues processing remaining instances
   - A summary of failures is provided at the end
3. For each command execution:
   - The script waits briefly for the command to complete
   - Fetches and logs the actual command output
   - Checks the command status
   - Records both successful and failed executions
4. The function returns a detailed results object containing:
   - List of successfully processed instances with their command IDs and outputs
   - List of failed instances with their error messages

Example response:
```json
{
    "statusCode": 200,
    "body": {
        "message": "Container restart initiated successfully",
        "results": {
            "successful": [
                {
                    "instance_id": "i-1234567890abcdef0",
                    "command_id": "12345",
                    "status": "Success",
                    "output": "Restarting jplatform container: abc123def456\nSuccessfully restarted jplatform container"
                }
            ],
            "failed": [
                {
                    "instance_id": "i-0987654321fedcba0",
                    "error": "Command failed with status Failed: No jplatform container found running"
                }
            ]
        },
        "timestamp": "2024-01-01T03:00:00.000Z"
    }
}
```