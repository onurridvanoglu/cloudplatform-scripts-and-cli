import boto3
import json
import logging
import os
from datetime import datetime

# Set up logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Initialize AWS clients
ssm = boto3.client('ssm')
ec2 = boto3.client('ec2')

def get_running_instances():
    """Get running EC2 instances based on configuration"""
    try:
        filters = [{'Name': 'instance-state-name', 'Values': ['running']}]
        
        # Check for specific instance IDs in environment variable
        specific_instances = os.environ.get('TARGET_INSTANCE_IDS', '')
        if specific_instances:
            instance_ids = [id.strip() for id in specific_instances.split(',')]
            logger.info(f"Filtering for specific instances: {instance_ids}")
            return instance_ids
            
        # Check for instance tags in environment variables
        target_tag_key = os.environ.get('TARGET_TAG_KEY', '')
        target_tag_value = os.environ.get('TARGET_TAG_VALUE', '')
        
        if target_tag_key and target_tag_value:
            filters.append({
                'Name': f'tag:{target_tag_key}',
                'Values': [target_tag_value]
            })
            logger.info(f"Filtering instances by tag {target_tag_key}={target_tag_value}")
        
        instances = []
        paginator = ec2.get_paginator('describe_instances')
        for page in paginator.paginate(Filters=filters):
            for reservation in page['Reservations']:
                instances.extend(reservation['Instances'])
        
        instance_ids = [inst['InstanceId'] for inst in instances]
        logger.info(f"Found {len(instance_ids)} matching instances")
        return instance_ids
        
    except Exception as e:
        logger.error(f"Error getting instances: {str(e)}")
        raise

def restart_containers(instance_ids):
    """Restart Docker containers on specified instances"""
    if not instance_ids:
        logger.info("No running instances found")
        return
    
    # Command to restart Docker containers
    command = """
        #!/bin/bash
        # Get jplatform container ID
        container=$(docker ps -q --filter "name=jplatform")
        
        if [ -n "$container" ]; then
            echo "Restarting jplatform container: $container"
            docker restart $container
            if [ $? -eq 0 ]; then
                echo "Successfully restarted jplatform container"
            else
                echo "Failed to restart jplatform container"
                exit 1
            fi
        else
            echo "No jplatform container found running"
            exit 1
        fi
    """
    
    try:
        response = ssm.send_command(
            InstanceIds=instance_ids,
            DocumentName='AWS-RunShellScript',
            Parameters={'commands': [command]},
            TimeoutSeconds=3600
        )
        
        command_id = response['Command']['CommandId']
        logger.info(f"Successfully initiated jplatform container restart with command ID: {command_id}")
        return command_id
        
    except Exception as e:
        logger.error(f"Error sending restart command: {str(e)}")
        raise

def lambda_handler(event, context):
    """Main Lambda handler"""
    try:
        # Get all running EC2 instances
        instance_ids = get_running_instances()
        logger.info(f"Found {len(instance_ids)} running instances")
        
        # Restart containers on all instances
        command_id = restart_containers(instance_ids)
        
        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': 'Container restart initiated successfully',
                'commandId': command_id,
                'instanceCount': len(instance_ids),
                'timestamp': datetime.now().isoformat()
            })
        }
        
    except Exception as e:
        logger.error(f"Error in lambda_handler: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps({
                'error': str(e),
                'timestamp': datetime.now().isoformat()
            })
        } 