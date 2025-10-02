#!/bin/bash

# Quick deployment script for Workplacify to GCP
# This script combines setup and deployment in one go
# It's idempotent - safe to run multiple times

set -e

PROJECT_ID=${1}
REGION="us-central1"

if [ -z "$PROJECT_ID" ]; then
  echo "❌ Error: Please provide your GCP project ID"
  echo "Usage: ./deploy/quick-deploy.sh your-project-id [--deploy-only|--setup-only]"
  exit 1
fi

echo "🚀 Starting Workplacify deployment to GCP..."
echo "Project ID: $PROJECT_ID"
echo "Region: $REGION"
echo ""

# Check if we should skip setup
if [ "$2" != "--deploy-only" ]; then
  # Step 1: Initial setup
  echo "📋 Step 1: Setting up GCP resources..."
  ./deploy/setup-gcp.sh $PROJECT_ID
  
  echo ""
  echo "✅ Setup complete!"
  
  # Check if secrets need updating
  echo "🔍 Checking if secrets need updating..."
  GOOGLE_CLIENT_ID=$(gcloud secrets versions access latest --secret="google-client-id" 2>/dev/null || echo "")
  
  if [ "$GOOGLE_CLIENT_ID" = "your-google-client-id" ] || [ -z "$GOOGLE_CLIENT_ID" ]; then
    echo ""
    echo "⚠️  Secrets contain placeholder values and need to be updated."
    echo ""
    echo "🔐 Step 2: Update secrets with your credentials"
    echo "Run the following command and provide your actual values:"
    echo "   ./deploy/update-secrets.sh $PROJECT_ID"
    echo ""
    echo "Then run deployment:"
    echo "   ./deploy/quick-deploy.sh $PROJECT_ID --deploy-only"
    
    if [ "$2" = "--setup-only" ]; then
      exit 0
    fi
    
    echo ""
    read -p "Do you want to update secrets now? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
      ./deploy/update-secrets.sh $PROJECT_ID
    else
      echo "⏸️  Skipping deployment. Update secrets first, then run:"
      echo "   ./deploy/quick-deploy.sh $PROJECT_ID --deploy-only"
      exit 0
    fi
  else
    echo "✅ Secrets appear to be configured"
  fi
fi

# Deploy the application
if [ "$2" != "--setup-only" ]; then
  echo ""
  echo "🚀 Step 3: Deploying application..."
  gcloud config set project $PROJECT_ID
  
  # Check if this is the first deployment
  SERVICE_EXISTS=$(gcloud run services list --filter="metadata.name:workplacify-app" --format="value(metadata.name)" | wc -l)
  
  if [ "$SERVICE_EXISTS" -eq 0 ]; then
    echo "📦 First deployment - this may take a few minutes..."
  else
    echo "🔄 Updating existing service..."
  fi
  
  gcloud builds submit --config cloudbuild.yaml .
  
  # Get the service URL
  SERVICE_URL=$(gcloud run services describe workplacify-app --region=$REGION --format="value(status.url)" 2>/dev/null || echo "")
  
  echo ""
  echo "✅ Deployment complete!"
  
  if [ -n "$SERVICE_URL" ]; then
    echo "🌐 Your app is available at: $SERVICE_URL"
    echo ""
    echo "📝 Next steps:"
    echo "1. Update OAuth redirect URIs:"
    echo "   - Google: $SERVICE_URL/api/auth/callback/google"
    echo "   - Microsoft: $SERVICE_URL/api/auth/callback/microsoft-entra-id"
    echo "2. Test your application at: $SERVICE_URL"
    echo "3. Check health endpoint: $SERVICE_URL/api/trpc/healthcheck"
  else
    echo "⚠️  Could not retrieve service URL. Check Cloud Run console."
  fi
fi