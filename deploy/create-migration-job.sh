#!/bin/bash

# Create Migration Job for Workplacify
# This script creates a Cloud Run job specifically for running database migrations

set -e

PROJECT_ID=${1:-$(gcloud config get-value project)}
REGION="us-central1"
DB_INSTANCE_NAME="workplacify-db"

if [ -z "$PROJECT_ID" ]; then
  echo "❌ Error: Please provide project ID or set it in gcloud config"
  echo "Usage: $0 your-project-id"
  exit 1
fi

echo "🔄 Creating migration job for project: $PROJECT_ID"

# Ensure the service account has all necessary permissions
echo "🔑 Checking and setting up IAM permissions..."
SERVICE_ACCOUNT="workplacify-app-sa@$PROJECT_ID.iam.gserviceaccount.com"

# Function to check and grant permission if needed
grant_permission_if_needed() {
  local role=$1
  local description=$2
  
  if ! gcloud projects get-iam-policy $PROJECT_ID --flatten="bindings[].members" --format="value(bindings.role)" --filter="bindings.members:serviceAccount:$SERVICE_ACCOUNT AND bindings.role:$role" | grep -q "$role"; then
    echo "  Adding $description permission..."
    gcloud projects add-iam-policy-binding $PROJECT_ID \
      --member="serviceAccount:$SERVICE_ACCOUNT" \
      --role="$role" --quiet
  else
    echo "  ✅ $description permission already exists"
  fi
}

# Grant necessary permissions
grant_permission_if_needed "roles/cloudsql.client" "Cloud SQL Client"
grant_permission_if_needed "roles/cloudsql.instanceUser" "Cloud SQL Instance User"
grant_permission_if_needed "roles/secretmanager.secretAccessor" "Secret Manager Access"

# Get the latest app image (we'll use the same image that contains our migration code)
LATEST_IMAGE="us-docker.pkg.dev/innate-beacon-396214/gcr.io/workplacify-app:build-9bb7b545-d433-4ecb-8aea-bc9b1fac84a4"

if [ -z "$LATEST_IMAGE" ]; then
  echo "❌ Error: No deployed app found. Please deploy the app first with:"
  echo "   gcloud builds submit --config cloudbuild.yaml ."
  exit 1
fi

echo "📦 Using image: $LATEST_IMAGE"

# Delete existing job if it exists
if gcloud run jobs describe migration-job --region=$REGION >/dev/null 2>&1; then
  echo "🗑️ Deleting existing migration job..."
  gcloud run jobs delete migration-job --region=$REGION --quiet
fi

# Create the migration job with proper configuration
echo "🚀 Creating migration job..."
gcloud run jobs create migration-job \
  --image="$LATEST_IMAGE" \
  --region=$REGION \
  --task-timeout=600 \
  --memory=512Mi \
  --cpu=1 \
  --max-retries=3 \
  --parallelism=1 \
  --set-secrets="DATABASE_URL=database-url:latest" \
  --service-account="workplacify-app-sa@$PROJECT_ID.iam.gserviceaccount.com" \
  --set-cloudsql-instances="$PROJECT_ID:$REGION:$DB_INSTANCE_NAME" \
  --command="npm" \
  --args="run,migrate"

echo "✅ Migration job created successfully!"
echo ""
echo "📝 To run migrations:"
echo "   gcloud run jobs execute migration-job --region=$REGION --wait"