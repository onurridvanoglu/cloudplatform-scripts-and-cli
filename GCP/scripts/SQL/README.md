# GCP Cloud SQL Inventory Script

This script generates a detailed inventory of all Cloud SQL instances across accessible GCP projects.

## Usage

Run the script with:

    ./GCP-SQL-inventory.sh [OPTIONS]

### Options

- `-h, --help`           Show help message
- `-o, --output FILE`    Specify output file (default: gcp-sql-instances-all-projects_TIMESTAMP.csv)
- `-f, --filter FILTER`  Filter projects (e.g., 'name:prod-*' or 'labels.env=prod')

## Output Fields

The script generates a CSV file with the following columns:

- project: GCP Project ID
- instance_name: SQL instance name
- database_version: Database engine version
- tier: Machine tier
- region: GCP region
- availability_type: ZONAL or REGIONAL
- storage_size_gb: Storage size in GB
- backup_enabled: Backup configuration status
- private_ip: Private IP address
- public_ip: Public IP address
- state: Instance state
- creation_time: Instance creation time
- labels: Instance labels

## Output Files

The script generates two files:
1. CSV inventory file with timestamp (see template.csv for format)
2. Log file with execution details

## Example

    ./GCP-SQL-inventory.sh -o sql-inventory.csv -f "labels.env=prod"

This will generate an inventory of all Cloud SQL instances in projects with label "env=prod" and save it to sql-inventory.csv. 