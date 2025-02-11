# Docker Container Restart Lambda Function

This Lambda function automatically restarts Docker containers running on EC2 instances on a scheduled basis.

## Prerequisites

1. EC2 instances must have:
   - AWS Systems Manager Agent (SSM Agent) installed
   - Docker installed and running
   - An IAM role that allows Systems Manager access

2. The Lambda function requires an IAM role with the following permissions:
   - AWSLambdaBasicExecutionRole
   - EC2 Read permissions
   - Systems Manager SendCommand permissions

## Configuration Options

You can configure which instances to target using Lambda environment variables:

1. **Specific Instance IDs**:
   - Set `TARGET_INSTANCE_IDS` environment variable
   - Format: Comma-separated list of instance IDs
   - Example: `i-1234567890abcdef0,i-0987654321fedcba0`

2. **Instance Tags**:
   - Set `TARGET_TAG_KEY` and `TARGET_TAG_VALUE` environment variables
   - Example: 
     - `TARGET_TAG_KEY`: `Environment`
     - `TARGET_TAG_VALUE`: `Production`

If no configuration is provided, the function will target all running instances.

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

## Monitoring

The function logs to CloudWatch Logs. You can monitor:
- Function execution status
- Number of instances processed
- Container restart status for each instance

## Customization

To modify which containers are restarted, edit the shell command in the `restart_containers()` function. The current script restarts all running containers, but you can add filters based on container names, labels, or other criteria.

## Troubleshooting

Common issues:
1. SSM Agent not running on EC2 instances
2. Insufficient IAM permissions
3. Docker service not running on instances
4. Network connectivity issues

Check CloudWatch Logs for detailed error messages and execution status. 