#!/bin/bash

# Set output CSV file
OUTPUT_FILE="ecr-repositories.csv"

# Create CSV header
echo "Repository Name,Repository URI,Created Date,Registry ID" > $OUTPUT_FILE

# Get ECR repositories and format output to CSV
aws ecr describe-repositories --query 'repositories[].[repositoryName,repositoryUri,createdAt,registryId]' --output text | while read -r line; do
    # Convert space-separated values to comma-separated
    echo "$line" | sed 's/\t/,/g' >> $OUTPUT_FILE
done

echo "ECR repositories have been exported to $OUTPUT_FILE" 