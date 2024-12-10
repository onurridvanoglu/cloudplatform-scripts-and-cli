# GCP Scripts Documentation

This directory contains scripts for gathering inventory information from Google Cloud Platform (GCP) resources.

## Available Scripts

1. [Compute Engine Inventory](Compute-Engine/README.md) - Inventory of all GCP Compute Engine instances
2. [Cloud SQL Inventory](SQL/README.md) - Inventory of all GCP Cloud SQL instances
3. [Cloud Storage Inventory](Cloud-Storage/README.md) - Inventory of all GCP Cloud Storage buckets

## Prerequisites

1. Google Cloud SDK (gcloud) installed and configured
2. Appropriate IAM permissions:
   - compute.instances.list
   - compute.projects.get
   - cloudsql.instances.list
   - storage.buckets.list
   - resourcemanager.projects.list

Each script directory contains its own README with detailed usage instructions and a template.csv showing the expected output format.