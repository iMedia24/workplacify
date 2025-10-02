#!/bin/bash

# Simple deployment script that bypasses Docker build issues
# This deploys directly using gcloud run deploy with source

set -e

PROJECT_ID=${1:-"innate-beacon-396214"}
REGION="us-central1"

if [ -z "$PROJECT_ID" ]; then
  echo "❌ Error: Please provide your GCP project ID"
  echo "Usage: $0 your-project-id"
  exit 1
fi

echo "🚀 Deploying Workplacify using Cloud Run source deployment..."
echo "Project ID: $PROJECT_ID"

# Set the project
gcloud config set project $PROJECT_ID

# Deploy directly from source (bypasses Docker build issues)
echo "📦 Deploying from source..."
gcloud run deploy workplacify-app \
  --source . \
  --region=$REGION \
  --platform=managed \
  --allow-unauthenticated \
  --port=3000 \
  --cpu=1 \
  --memory=512Mi \
  --min-instances=0 \
  --max-instances=10 \
  --concurrency=80 \
  --timeout=300 \
  --set-env-vars=NODE_ENV=production \
  --set-secrets=DATABASE_URL=database-url:latest,NEXTAUTH_SECRET=nextauth-secret:latest,GOOGLE_CLIENT_ID=google-client-id:latest,GOOGLE_CLIENT_SECRET=google-client-secret:latest,CLOUDINARY_API_SECRET=cloudinary-api-secret:latest,CLOUDINARY_API_KEY=cloudinary-api-key:latest,CLOUDINARY_NAME=cloudinary-name:latest,MICROSOFT_ENTRA_CLIENT_ID=microsoft-entra-client-id:latest,MICROSOFT_ENTRA_CLIENT_SECRET=microsoft-entra-client-secret:latest,MICROSOFT_ENTRA_ISSUER=microsoft-entra-issuer:latest,ADMIN_EMAILS=admin-emails:latest \
  --service-account=workplacify-app-sa@$PROJECT_ID.iam.gserviceaccount.com \
  --add-cloudsql-instances=$PROJECT_ID:us-central1:workplacify-db

# Get the service URL
SERVICE_URL=$(gcloud run services describe workplacify-app --region=$REGION --format="value(status.url)" 2>/dev/null || echo "")

echo ""
echo "✅ Deployment complete!"

if [ -n "$SERVICE_URL" ]; then
  echo "🌐 Your app is available at: $SERVICE_URL"
  echo ""
  echo "📝 Next steps:"
  echo "1. Run database migrations:"
  echo "   gcloud run jobs create migration-job --image=gcr.io/google.com/cloudsdktool/cloud-sdk:latest --region=$REGION --task-timeout=600 --set-secrets=DATABASE_URL=database-url:latest"
  echo ""
  echo "2. Update OAuth redirect URIs:"
  echo "   - Google: $SERVICE_URL/api/auth/callback/google"
  echo "   - Microsoft: $SERVICE_URL/api/auth/callback/microsoft-entra-id"
  echo ""
  echo "3. Test your application at: $SERVICE_URL"
else
  echo "⚠️  Could not retrieve service URL. Check Cloud Run console."
fi