# GCP Cloud Storage Inventory Script

This script generates a detailed inventory of all Cloud Storage buckets across accessible GCP projects.

## Usage

Run the script with:

    ./Cloud-Storage-inventory.sh [OPTIONS]

### Options

- `-h, --help`           Show help message
- `-o, --output FILE`    Specify output file (default: gcp-buckets-all-projects_TIMESTAMP.csv)
- `-f, --filter FILTER`  Filter projects (e.g., 'name:prod-*' or 'labels.env=prod')

## Output Fields

The script generates a CSV file with the following columns:

- project: GCP Project ID
- bucket_name: Name of the storage bucket
- location: Bucket location (region/multi-region)
- storage_class: Storage class (STANDARD, NEARLINE, COLDLINE, ARCHIVE)
- versioning: Object versioning status (true/false)
- lifecycle_rules: Number of lifecycle rules
- retention_policy: Whether bucket has retention policy (yes/no)
- public_access: Public access prevention setting
- labels: Bucket labels
- creation_time: Bucket creation time

## Output Files

The script generates two files:
1. CSV inventory file with timestamp (see template.csv for format)
2. Log file with execution details

## Example

    ./Cloud-Storage-inventory.sh -o storage-inventory.csv -f "labels.env=prod"

This will generate an inventory of all Cloud Storage buckets in projects with label "env=prod" and save it to storage-inventory.csv. 