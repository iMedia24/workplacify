#!/bin/bash

# Run Database Migrations for Workplacify
# This script safely executes database migrations using Cloud Run Jobs

set -e

PROJECT_ID=${1:-$(gcloud config get-value project)}
REGION="us-central1"

if [ -z "$PROJECT_ID" ]; then
  echo "❌ Error: Please provide project ID or set it in gcloud config"
  echo "Usage: $0 your-project-id"
  exit 1
fi

echo "🔄 Running database migrations for project: $PROJECT_ID"

# Check if migration job exists
if ! gcloud run jobs describe migration-job --region=$REGION >/dev/null 2>&1; then
  echo "❌ Migration job not found. Creating it first..."
  ./deploy/create-migration-job.sh "$PROJECT_ID"
fi

# Execute the migration job
echo "🚀 Executing migration job..."
gcloud run jobs execute migration-job --region=$REGION --wait

# Check the execution status
EXECUTION_STATUS=$(gcloud run jobs executions list --job=migration-job --region=$REGION --limit=1 --format="value(status.conditions[0].type)")

if [ "$EXECUTION_STATUS" = "Completed" ]; then
  echo "✅ Migrations completed successfully!"
else
  echo "❌ Migration failed. Check logs with:"
  echo "   gcloud run jobs executions logs migration-job --region=$REGION"
  exit 1
fi