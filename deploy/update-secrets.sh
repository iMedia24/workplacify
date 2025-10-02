#!/bin/bash

# Script to update GCP Secret Manager with your actual values
# Run this after setup-gcp.sh to populate secrets with real values
# It's idempotent - safe to run multiple times

set -e

PROJECT_ID=${1:-"your-project-id"}

if [ "$PROJECT_ID" = "your-project-id" ]; then
  echo "❌ Error: Please provide your actual GCP project ID"
  echo "Usage: $0 your-actual-project-id"
  exit 1
fi

echo "🔐 Updating secrets with actual values..."
echo "Project ID: $PROJECT_ID"

gcloud config set project $PROJECT_ID

# Function to update secret with current value display
update_secret() {
  local secret_name=$1
  local description=$2
  local optional=${3:-false}
  
  # Get current value (first 20 chars for security)
  current_value=$(gcloud secrets versions access latest --secret="$secret_name" 2>/dev/null || echo "")
  current_display=""
  
  if [ -n "$current_value" ] && [ "$current_value" != "your-$secret_name" ]; then
    if [ ${#current_value} -gt 20 ]; then
      current_display=" (current: ${current_value:0:20}...)"
    else
      current_display=" (current: $current_value)"
    fi
  fi
  
  echo ""
  echo "📝 $description$current_display"
  
  if [ "$optional" = "true" ]; then
    read -p "Update this secret? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
      echo "⏭️  Skipping $secret_name"
      return
    fi
  fi
  
  read -s -p "Enter new value (or press Enter to keep current): " value
  echo
  
  if [ -n "$value" ]; then
    echo -n "$value" | gcloud secrets versions add $secret_name --data-file=-
    echo "✅ Updated $secret_name"
  else
    echo "⏭️  Keeping current value for $secret_name"
  fi
}

# Function to update secret with visible input (for non-sensitive data)
update_secret_visible() {
  local secret_name=$1
  local description=$2
  
  current_value=$(gcloud secrets versions access latest --secret="$secret_name" 2>/dev/null || echo "")
  
  echo ""
  echo "📝 $description"
  if [ -n "$current_value" ]; then
    echo "Current value: $current_value"
  fi
  
  read -p "Enter new value (or press Enter to keep current): " value
  
  if [ -n "$value" ]; then
    echo -n "$value" | gcloud secrets versions add $secret_name --data-file=-
    echo "✅ Updated $secret_name"
  else
    echo "⏭️  Keeping current value for $secret_name"
  fi
}

echo ""
echo "🔍 Current secret status:"
for secret in google-client-id google-client-secret cloudinary-api-key cloudinary-api-secret cloudinary-name microsoft-entra-client-id microsoft-entra-client-secret microsoft-entra-issuer admin-emails; do
  current=$(gcloud secrets versions access latest --secret="$secret" 2>/dev/null || echo "NOT_FOUND")
  if [[ "$current" == "your-"* ]] || [ "$current" = "NOT_FOUND" ]; then
    echo "❌ $secret: needs updating"
  else
    echo "✅ $secret: configured"
  fi
done

echo ""
echo "📋 Update the secrets below. Press Enter to keep current values."

# Update each secret with actual values
update_secret "google-client-id" "Google OAuth Client ID (from Google Cloud Console)"
update_secret "google-client-secret" "Google OAuth Client Secret"
update_secret "cloudinary-api-key" "Cloudinary API Key"
update_secret "cloudinary-api-secret" "Cloudinary API Secret"
update_secret_visible "cloudinary-name" "Cloudinary Cloud Name"

# Optional Microsoft Entra ID secrets
echo ""
echo "🔵 Microsoft Entra ID (optional - skip if not using Microsoft authentication)"
update_secret "microsoft-entra-client-id" "Microsoft Entra Client ID" true
update_secret "microsoft-entra-client-secret" "Microsoft Entra Client Secret" true
update_secret_visible "microsoft-entra-issuer" "Microsoft Entra Issuer URL" 

# Admin emails
update_secret_visible "admin-emails" "Admin emails (pipe-separated, e.g., admin@company.com|admin2@company.com)"

echo ""
echo "✅ Secret update process completed!"

# Verify critical secrets are set
echo ""
echo "🔍 Verifying critical secrets..."
critical_secrets=("google-client-id" "google-client-secret" "cloudinary-api-key" "cloudinary-api-secret" "cloudinary-name")
all_good=true

for secret in "${critical_secrets[@]}"; do
  current=$(gcloud secrets versions access latest --secret="$secret" 2>/dev/null || echo "")
  if [[ "$current" == "your-"* ]] || [ -z "$current" ]; then
    echo "⚠️  $secret still needs a real value"
    all_good=false
  fi
done

if [ "$all_good" = true ]; then
  echo "✅ All critical secrets are configured!"
  echo ""
  echo "🚀 Ready to deploy! Run:"
  echo "   ./deploy/quick-deploy.sh $PROJECT_ID --deploy-only"
else
  echo ""
  echo "⚠️  Some critical secrets still need real values."
  echo "🔄 Run this script again to update them:"
  echo "   ./deploy/update-secrets.sh $PROJECT_ID"
fi