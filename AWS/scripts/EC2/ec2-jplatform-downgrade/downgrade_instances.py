#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
EC2 Instance Type Downgrade Script

This script identifies EC2 instances with the tag 'Category: Jplatform' and 
downgrades their instance types from r5a.xlarge or r5a.2xlarge to r5a.large.
It specifically targets instances with names from jplatform-isbasi-61 to jplatform-isbasi-134.

Usage:
    python downgrade_instances.py [--dry-run] [--profile PROFILE] [--region REGION]

Options:
    --dry-run       Run in dry-run mode without making any changes
    --profile       AWS profile name to use
    --region        AWS region to use (default: eu-west-1)
    --parallel      Number of instances to process in parallel (default: 40)
    --help          Show this help message and exit
"""

import argparse
import boto3
import logging
import re
import sys
import time
from concurrent.futures import ThreadPoolExecutor
from botocore.exceptions import ClientError

# Set up logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.StreamHandler(),
        logging.FileHandler('ec2_downgrade.log')
    ]
)
logger = logging.getLogger(__name__)

def parse_arguments():
    """Parse command line arguments"""
    parser = argparse.ArgumentParser(description='Downgrade EC2 instance types for jplatform-isbasi instances')
    parser.add_argument('--dry-run', action='store_true', help='Perform a dry run without making any changes')
    parser.add_argument('--profile', help='AWS profile to use')
    parser.add_argument('--region', default='eu-west-1', help='AWS region to use')
    parser.add_argument('--parallel', type=int, default=40, help='Number of instances to process in parallel')
    return parser.parse_args()

def get_ec2_client(profile=None, region='eu-west-1'):
    """
    Initialize and return an EC2 client
    
    Args:
        profile (str): AWS profile name
        region (str): AWS region
        
    Returns:
        boto3.client: EC2 client
    """
    try:
        if profile:
            session = boto3.Session(profile_name=profile, region_name=region)
        else:
            session = boto3.Session(region_name=region)
        
        return session.client('ec2')
    except Exception as e:
        logger.error(f"Failed to initialize EC2 client: {str(e)}")
        sys.exit(1)

def get_jplatform_instances(ec2_client):
    """
    Get all EC2 instances with the tag Category=Jplatform
    
    Args:
        ec2_client (boto3.client): EC2 client
        
    Returns:
        list: List of EC2 instance dictionaries
    """
    instances = []
    try:
        # Define filter for instances with the tag Category=Jplatform
        filters = [
            {
                'Name': 'tag:Category', 
                'Values': ['Jplatform']
            },
            {
                'Name': 'instance-state-name',
                'Values': ['running', 'stopped']
            }
        ]
        
        # Use paginator for handling large lists of instances
        paginator = ec2_client.get_paginator('describe_instances')
        for page in paginator.paginate(Filters=filters):
            for reservation in page['Reservations']:
                instances.extend(reservation['Instances'])
                
        logger.info(f"Found {len(instances)} instances with tag Category=Jplatform")
        return instances
    except ClientError as e:
        logger.error(f"Error getting instances: {str(e)}")
        return []

def filter_target_instances(instances):
    """
    Filter instances by name pattern jplatform-isbasi-61 to jplatform-isbasi-134
    
    Args:
        instances (list): List of EC2 instance dictionaries
        
    Returns:
        list: Filtered list of EC2 instance dictionaries
    """
    filtered_instances = []
    pattern = re.compile(r'jplatform-isbasi-(\d+)')
    
    for instance in instances:
        # Get the Name tag
        instance_name = None
        for tag in instance.get('Tags', []):
            if tag['Key'] == 'Name':
                instance_name = tag['Value']
                break
        
        if not instance_name:
            continue
            
        # Check if it follows the pattern
        match = pattern.match(instance_name)
        if match:
            instance_number = int(match.group(1))
            
            # Include only instances from 61 to 134
            if 61 <= instance_number <= 134 and instance_number != 135:
                # Add instance name for better logging
                instance['NameTag'] = instance_name
                filtered_instances.append(instance)
                
    logger.info(f"Filtered to {len(filtered_instances)} target instances in the range jplatform-isbasi-61 to jplatform-isbasi-134")
    return filtered_instances

def needs_downgrade(instance):
    """
    Check if the instance needs to be downgraded
    
    Args:
        instance (dict): EC2 instance dictionary
        
    Returns:
        bool: True if instance needs downgrade, False otherwise
    """
    instance_type = instance['InstanceType']
    instance_name = instance.get('NameTag', instance['InstanceId'])
    
    # Skip instances that are already r5a.large
    if instance_type == 'r5a.large':
        logger.info(f"Instance {instance_name} ({instance['InstanceId']}) is already r5a.large, skipping")
        return False
        
    # Only downgrade r5a.xlarge or r5a.2xlarge
    if instance_type in ['r5a.xlarge', 'r5a.2xlarge']:
        logger.info(f"Instance {instance_name} ({instance['InstanceId']}) is {instance_type}, will be downgraded to r5a.large")
        return True
        
    # Skip other instance types
    logger.info(f"Instance {instance_name} ({instance['InstanceId']}) is {instance_type}, which is not a target for downgrade")
    return False

def downgrade_instance(ec2_client, instance, dry_run=False):
    """
    Downgrade an instance to r5a.large
    
    Args:
        ec2_client (boto3.client): EC2 client
        instance (dict): EC2 instance dictionary
        dry_run (bool): If True, don't make any changes
        
    Returns:
        dict: Result of the operation
    """
    instance_id = instance['InstanceId']
    instance_name = instance.get('NameTag', instance_id)
    current_type = instance['InstanceType']
    target_type = 'r5a.large'
    
    result = {
        'instance_id': instance_id,
        'instance_name': instance_name,
        'original_type': current_type,
        'target_type': target_type,
        'success': False,
        'error': None
    }
    
    try:
        logger.info(f"Starting downgrade process for {instance_name} ({instance_id})")
        
        # Check current state
        current_state = instance['State']['Name']
        was_running = current_state == 'running'
        
        if dry_run:
            logger.info(f"DRY RUN: Would stop instance {instance_name} ({instance_id})")
            logger.info(f"DRY RUN: Would modify {instance_name} ({instance_id}) from {current_type} to {target_type}")
            if was_running:
                logger.info(f"DRY RUN: Would start instance {instance_name} ({instance_id})")
            result['success'] = True
            return result
            
        # Stop the instance if it's running
        if current_state == 'running':
            logger.info(f"Stopping instance {instance_name} ({instance_id})...")
            ec2_client.stop_instances(InstanceIds=[instance_id])
            
            # Wait for the instance to stop
            waiter = ec2_client.get_waiter('instance_stopped')
            waiter.wait(InstanceIds=[instance_id])
            logger.info(f"Instance {instance_name} ({instance_id}) stopped successfully")
            
        # Modify instance type
        logger.info(f"Modifying instance {instance_name} ({instance_id}) from {current_type} to {target_type}...")
        ec2_client.modify_instance_attribute(
            InstanceId=instance_id,
            InstanceType={'Value': target_type}
        )
        logger.info(f"Instance {instance_name} ({instance_id}) type modified to {target_type}")
        
        # Start the instance if it was previously running
        if was_running:
            logger.info(f"Starting instance {instance_name} ({instance_id})...")
            ec2_client.start_instances(InstanceIds=[instance_id])
            
            # Wait for the instance to start
            waiter = ec2_client.get_waiter('instance_running')
            waiter.wait(InstanceIds=[instance_id])
            logger.info(f"Instance {instance_name} ({instance_id}) started successfully")
            
        result['success'] = True
        return result
        
    except Exception as e:
        error_msg = f"Error downgrading instance {instance_name} ({instance_id}): {str(e)}"
        logger.error(error_msg)
        result['error'] = str(e)
        return result

def process_instances(ec2_client, instances, dry_run=False, parallel=40):
    """
    Process instances for downgrading
    
    Args:
        ec2_client (boto3.client): EC2 client
        instances (list): List of EC2 instance dictionaries
        dry_run (bool): If True, don't make any changes
        parallel (int): Number of instances to process in parallel
        
    Returns:
        dict: Results of the operations
    """
    results = {
        'total': len(instances),
        'downgraded': 0,
        'skipped': 0,
        'failed': 0,
        'details': {
            'downgraded': [],
            'skipped': [],
            'failed': []
        }
    }
    
    # Filter for instances that need downgrading
    to_downgrade = []
    for instance in instances:
        if needs_downgrade(instance):
            to_downgrade.append(instance)
        else:
            instance_name = instance.get('NameTag', instance['InstanceId'])
            results['skipped'] += 1
            results['details']['skipped'].append({
                'instance_id': instance['InstanceId'],
                'instance_name': instance_name,
                'instance_type': instance['InstanceType'],
                'reason': 'Already r5a.large or not a target type'
            })
    
    logger.info(f"Found {len(to_downgrade)} instances that need downgrading")
    
    if not to_downgrade:
        return results
        
    # Process instances in parallel
    with ThreadPoolExecutor(max_workers=parallel) as executor:
        future_to_instance = {
            executor.submit(downgrade_instance, ec2_client, instance, dry_run): instance
            for instance in to_downgrade
        }
        
        for future in future_to_instance:
            result = future.result()
            if result['success']:
                results['downgraded'] += 1
                results['details']['downgraded'].append(result)
            else:
                results['failed'] += 1
                results['details']['failed'].append(result)
    
    return results

def main():
    """Main function"""
    args = parse_arguments()
    
    # Set up dry run mode notice
    if args.dry_run:
        logger.info("Running in DRY RUN mode - no changes will be made")
    
    # Initialize EC2 client
    ec2_client = get_ec2_client(args.profile, args.region)
    
    # Get jplatform instances
    all_instances = get_jplatform_instances(ec2_client)
    if not all_instances:
        logger.warning("No instances found with tag Category=Jplatform")
        return
        
    # Filter target instances
    target_instances = filter_target_instances(all_instances)
    if not target_instances:
        logger.warning("No instances found matching the required name pattern")
        return
        
    # Process instances
    results = process_instances(ec2_client, target_instances, args.dry_run, args.parallel)
    
    # Display summary
    logger.info("\n" + "="*50)
    logger.info("SUMMARY")
    logger.info("="*50)
    logger.info(f"Total instances processed: {results['total']}")
    logger.info(f"Instances downgraded: {results['downgraded']}")
    logger.info(f"Instances skipped: {results['skipped']}")
    logger.info(f"Instances failed: {results['failed']}")
    logger.info("="*50)
    
    if results['failed'] > 0:
        logger.warning("Some instance downgrades failed. See log for details.")
        return 1
    return 0

if __name__ == "__main__":
    sys.exit(main()) 