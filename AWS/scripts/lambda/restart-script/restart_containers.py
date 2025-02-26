import boto3
import json
import logging
import os
import time  # Add import for time.sleep
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
            filters = [
                {'Name': 'instance-state-name', 'Values': ['running']},
                {'Name': f'tag:{target_tag_key}', 'Values': [target_tag_value]}
            ]
            
            logger.info(f"Filtering instances by tag {target_tag_key}={target_tag_value}")
            
            instances = []
            paginator = ec2.get_paginator('describe_instances')
            for page in paginator.paginate(Filters=filters):
                for reservation in page['Reservations']:
                    instances.extend(reservation['Instances'])
            
            instance_ids = [inst['InstanceId'] for inst in instances]
            logger.info(f"Found {len(instance_ids)} matching instances")
            return instance_ids
        
        # If neither specific instances nor tags are provided, raise an error
        raise ValueError(
            "No target instances specified. Please set either TARGET_INSTANCE_IDS "
            "or both TARGET_TAG_KEY and TARGET_TAG_VALUE environment variables."
        )
        
    except Exception as e:
        logger.error(f"Error getting instances: {str(e)}")
        raise

def get_command_output(command_id, instance_id):
    """Get the command output from SSM for a specific instance"""
    try:
        # Wait briefly for command to complete
        time.sleep(2)
        response = ssm.get_command_invocation(
            CommandId=command_id,
            InstanceId=instance_id
        )
        return {
            'Status': response['Status'],
            'Output': response.get('StandardOutputContent', ''),
            'Error': response.get('StandardErrorContent', '')
        }
    except Exception as e:
        logger.error(f"Failed to get command output for instance {instance_id}: {str(e)}")
        return {
            'Status': 'Failed',
            'Output': '',
            'Error': f"Failed to get command output: {str(e)}"
        }

def restart_containers(instance_ids):
    """Restart Docker containers on specified instances"""
    if not instance_ids:
        logger.info("No running instances found")
        return
    
    # Command to restart Docker containers with minimal state logging
    command = """
        #!/bin/bash
        
        # Get current timestamp
        timestamp=$(date '+%Y-%m-%d %H:%M:%S')
        
        # Log separator and timestamp
        echo "\\n=== Container Restart Event: $timestamp ===" >> /var/log/container_stats.log
        
        # Log current state
        echo "Current Container Status:" >> /var/log/container_stats.log
        sudo docker ps -a >> /var/log/container_stats.log
        
        echo "\\nContainer Stats:" >> /var/log/container_stats.log
        sudo docker stats --no-stream >> /var/log/container_stats.log
        
        # Get jplatform container ID and restart
        container=$(sudo docker ps -aq --filter "name=jplatform")
        
        if [ -n "$container" ]; then
            sudo docker restart $container
            if [ $? -ne 0 ]; then
                echo "Failed to restart jplatform container"
                exit 1
            fi
        else
            echo "No jplatform container found running"
            exit 1
        fi
    """
    
    results = {
        'successful': [],
        'failed': []
    }
    
    # Process instances one by one with delay
    for i, instance_id in enumerate(instance_ids):
        try:
            # Add 5-second delay between instances (except for the first one)
            if i > 0:
                logger.info("Waiting 5 seconds before processing next instance...")
                time.sleep(5)
            
            logger.info(f"Processing instance: {instance_id}")
            response = ssm.send_command(
                InstanceIds=[instance_id],
                DocumentName='AWS-RunShellScript',
                Parameters={'commands': [command]},
                TimeoutSeconds=3600
            )
            
            command_id = response['Command']['CommandId']
            logger.info(f"Initiated jplatform container restart on instance {instance_id} with command ID: {command_id}")
            
            # Get command output
            command_output = get_command_output(command_id, instance_id)
            logger.info(f"Command output for instance {instance_id}:")
            logger.info(f"Status: {command_output['Status']}")
            if command_output['Output']:
                logger.info(f"Output:\n{command_output['Output']}")
            if command_output['Error']:
                logger.info(f"Error:\n{command_output['Error']}")
            
            if command_output['Status'] in ['Success', 'InProgress']:
                results['successful'].append({
                    'instance_id': instance_id,
                    'command_id': command_id,
                    'status': command_output['Status'],
                    'output': command_output['Output']
                })
            else:
                raise Exception(f"Command failed with status {command_output['Status']}: {command_output['Error']}")
            
        except Exception as e:
            error_msg = f"Failed to process instance {instance_id}: {str(e)}"
            logger.error(error_msg)
            results['failed'].append({
                'instance_id': instance_id,
                'error': str(e)
            })
            continue
    
    # Log summary
    logger.info(f"Processing complete. Successfully processed {len(results['successful'])} instances, "
                f"Failed to process {len(results['failed'])} instances")
    
    if results['failed']:
        logger.error("Failed instances:")
        for failure in results['failed']:
            logger.error(f"Instance {failure['instance_id']}: {failure['error']}")
    
    return results

def lambda_handler(event, context):
    """Main Lambda handler"""
    try:
        # Get all running EC2 instances
        instance_ids = get_running_instances()
        logger.info(f"Found {len(instance_ids)} running instances")
        
        # Restart containers on all instances
        results = restart_containers(instance_ids)
        
        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': 'Container restart initiated successfully',
                'results': results,
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