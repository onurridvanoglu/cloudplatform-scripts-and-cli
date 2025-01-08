# GCP Compute Engine Inventory Script

This script generates a detailed inventory of all Compute Engine instances across accessible GCP projects.

## Usage

Run the script with:

    ./GCP-CE-inventory.sh [OPTIONS]

### Options

- `-h, --help`           Show help message
- `-o, --output FILE`    Specify output file (default: gcp-instances-all-projects_TIMESTAMP.csv)
- `-f, --filter FILTER`  Filter projects (e.g., 'name:prod-*' or 'labels.env=prod')

## Output Fields

The script generates a CSV file with the following columns:

- project: GCP Project ID
- name: Instance name
- zone: GCP zone where instance is running
- machine_type: Instance type (e.g., e2-medium)
- vcpu: Number of virtual CPUs
- memory_gb: Memory in GB
- status: Instance status
- network_ip: Internal IP address
- external_ip: External IP address (if any)
- disk_name: Attached disk name
- disk_size_gb: Disk size in GB
- creation_timestamp: Instance creation time
- tags: Instance tags
- labels: Instance labels

## Output Files

The script generates two files:
1. CSV inventory file with timestamp (see template.csv for format)
2. Log file with execution details

## Example

    ./GCP-CE-inventory.sh -o my-inventory.csv -f "name:prod-*"

This will generate an inventory of all Compute Engine instances in projects with names starting with "prod-" and save it to my-inventory.csv. 