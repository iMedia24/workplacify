#!/bin/bash

# GCP Setup Script for Workplacify App
# This script sets up the necessary GCP resources for deployment
# It's idempotent - safe to run multiple times

set -e

# Configuration
PROJECT_ID=${1:-"your-project-id"}
REGION="us-central1"
DB_INSTANCE_NAME="workplacify-db"
DB_NAME="workplacify"
DB_USER="workplacify_user"

echo "🚀 Setting up GCP resources for Workplacify..."
echo "Project ID: $PROJECT_ID"
echo "Region: $REGION"

# Validate project ID
if [ "$PROJECT_ID" = "your-project-id" ]; then
  echo "❌ Error: Please provide your actual GCP project ID"
  echo "Usage: $0 your-actual-project-id"
  exit 1
fi

# Set the project
gcloud config set project $PROJECT_ID

# Enable required APIs
echo "📡 Enabling required APIs..."
gcloud services enable \
  cloudbuild.googleapis.com \
  run.googleapis.com \
  sqladmin.googleapis.com \
  secretmanager.googleapis.com \
  containerregistry.googleapis.com

# Check if Cloud SQL instance exists
echo "🗄️ Setting up Cloud SQL PostgreSQL instance..."
INSTANCE_EXISTS=$(gcloud sql instances list --filter="name:$DB_INSTANCE_NAME" --format="value(name)" | wc -l)

if [ "$INSTANCE_EXISTS" -eq 0 ]; then
  echo "Creating new Cloud SQL instance..."
  gcloud sql instances create $DB_INSTANCE_NAME \
    --database-version=POSTGRES_15 \
    --tier=db-f1-micro \
    --region=$REGION \
    --storage-type=SSD \
    --storage-size=10GB \
    --storage-auto-increase \
    --backup-start-time=03:00 \
    --maintenance-window-day=SUN \
    --maintenance-window-hour=04 \
    --deletion-protection
else
  echo "✅ Cloud SQL instance already exists"
  
  # Check instance state and wait if necessary
  INSTANCE_STATE=$(gcloud sql instances describe $DB_INSTANCE_NAME --format="value(state)")
  echo "Instance state: $INSTANCE_STATE"
  
  if [ "$INSTANCE_STATE" = "PENDING_CREATE" ]; then
    echo "⏳ Instance is still being created. Waiting..."
    while [ "$INSTANCE_STATE" = "PENDING_CREATE" ]; do
      echo "   Still creating... (this can take 5-10 minutes)"
      sleep 30
      INSTANCE_STATE=$(gcloud sql instances describe $DB_INSTANCE_NAME --format="value(state)")
    done
  elif [ "$INSTANCE_STATE" = "STOPPED" ]; then
    echo "🔄 Starting stopped instance..."
    gcloud sql instances patch $DB_INSTANCE_NAME --activation-policy=ALWAYS
    echo "⏳ Waiting for instance to start..."
    sleep 60
  fi
fi

# Create database
echo "📊 Setting up database..."
DB_EXISTS=$(gcloud sql databases list --instance=$DB_INSTANCE_NAME --filter="name:$DB_NAME" --format="value(name)" | wc -l)
if [ "$DB_EXISTS" -eq 0 ]; then
  echo "Creating database..."
  gcloud sql databases create $DB_NAME --instance=$DB_INSTANCE_NAME
else
  echo "✅ Database already exists"
fi

# Create or update database user
echo "👤 Setting up database user..."
USER_EXISTS=$(gcloud sql users list --instance=$DB_INSTANCE_NAME --filter="name:$DB_USER" --format="value(name)" | wc -l)
DB_PASSWORD=$(openssl rand -base64 32)

if [ "$USER_EXISTS" -eq 0 ]; then
  echo "Creating database user..."
  gcloud sql users create $DB_USER \
    --instance=$DB_INSTANCE_NAME \
    --password=$DB_PASSWORD
else
  echo "✅ Database user exists, updating password..."
  gcloud sql users set-password $DB_USER \
    --instance=$DB_INSTANCE_NAME \
    --password=$DB_PASSWORD
fi

# Get the connection name
CONNECTION_NAME=$(gcloud sql instances describe $DB_INSTANCE_NAME --format="value(connectionName)")

# Create DATABASE_URL
DATABASE_URL="postgresql://$DB_USER:$DB_PASSWORD@localhost:5432/$DB_NAME?host=/cloudsql/$CONNECTION_NAME"

echo "🔐 Setting up secrets in Secret Manager..."

# Function to create or update secret
create_or_update_secret() {
  local secret_name=$1
  local secret_value=$2
  
  if gcloud secrets describe $secret_name >/dev/null 2>&1; then
    echo "✅ Secret $secret_name already exists, updating..."
    echo -n "$secret_value" | gcloud secrets versions add $secret_name --data-file=-
  else
    echo "Creating secret $secret_name..."
    echo -n "$secret_value" | gcloud secrets create $secret_name --data-file=-
  fi
}

# Create/update secrets
create_or_update_secret "database-url" "$DATABASE_URL"
create_or_update_secret "nextauth-secret" "$(openssl rand -base64 32)"
create_or_update_secret "nextauth-url" "https://your-app-url.run.app"

# Placeholder secrets - UPDATE THESE WITH YOUR ACTUAL VALUES
create_or_update_secret "google-client-id" "your-google-client-id"
create_or_update_secret "google-client-secret" "your-google-client-secret"
create_or_update_secret "cloudinary-api-key" "your-cloudinary-api-key"
create_or_update_secret "cloudinary-api-secret" "your-cloudinary-api-secret"
create_or_update_secret "cloudinary-name" "your-cloudinary-name"
create_or_update_secret "microsoft-entra-client-id" "your-microsoft-entra-client-id"
create_or_update_secret "microsoft-entra-client-secret" "your-microsoft-entra-client-secret"
create_or_update_secret "microsoft-entra-issuer" "your-microsoft-entra-issuer"
create_or_update_secret "admin-emails" "admin@yourcompany.com"

# Second pass: Ensure all secrets now have proper permissions (after creation)
echo ""
echo "🔑 Ensuring all secrets have proper permissions (second pass)..."
for secret in database-url nextauth-secret nextauth-url google-client-id google-client-secret cloudinary-api-key cloudinary-api-secret cloudinary-name microsoft-entra-client-id microsoft-entra-client-secret microsoft-entra-issuer admin-emails; do
  grant_secret_access $secret "serviceAccount:$CLOUD_BUILD_SA" "roles/secretmanager.secretAccessor"
  grant_secret_access $secret "serviceAccount:$COMPUTE_SA" "roles/secretmanager.secretAccessor"
  grant_secret_access $secret "serviceAccount:$CLOUD_RUN_SA" "roles/secretmanager.secretAccessor"
done

# Set up IAM permissions
echo "🔑 Setting up IAM permissions..."
PROJECT_NUMBER=$(gcloud projects describe $PROJECT_ID --format="value(projectNumber)")
CLOUD_BUILD_SA="$PROJECT_NUMBER@cloudbuild.gserviceaccount.com"
COMPUTE_SA="$PROJECT_NUMBER-compute@developer.gserviceaccount.com"

# Create Cloud Run service account if it doesn't exist
echo "🏃 Setting up Cloud Run service account..."
SA_EXISTS=$(gcloud iam service-accounts list --filter="email:workplacify-app-sa@$PROJECT_ID.iam.gserviceaccount.com" --format="value(email)" | wc -l)
if [ "$SA_EXISTS" -eq 0 ]; then
  echo "Creating Cloud Run service account..."
  gcloud iam service-accounts create workplacify-app-sa \
    --display-name="Workplacify App Service Account"
else
  echo "✅ Cloud Run service account already exists"
fi

CLOUD_RUN_SA="workplacify-app-sa@$PROJECT_ID.iam.gserviceaccount.com"

# Function to grant IAM permission if not already granted
grant_secret_access() {
  local secret_name=$1
  local member=$2
  local role=$3
  
  # Check if secret exists first
  if ! gcloud secrets describe $secret_name >/dev/null 2>&1; then
    echo "⚠️  Secret $secret_name does not exist yet, skipping permission grant..."
    return
  fi
  
  # Check if permission already exists
  EXISTING_BINDING=$(gcloud secrets get-iam-policy $secret_name --format="value(bindings[?role=='$role'].members[])" 2>/dev/null | grep -c "$member" || echo "0")
  
  if [ "$EXISTING_BINDING" -eq 0 ]; then
    echo "🔑 Granting $role to $member for $secret_name..."
    if gcloud secrets add-iam-policy-binding $secret_name \
      --member="$member" \
      --role="$role" >/dev/null 2>&1; then
      echo "✅ Successfully granted permission for $secret_name"
    else
      echo "❌ Failed to grant permission for $secret_name to $member"
    fi
  else
    echo "✅ Permission already exists for $secret_name ($member)"
  fi
}

# Grant permissions to all secrets (first pass - some secrets might not exist yet)
echo "🔑 Setting up initial secret permissions..."
for secret in database-url nextauth-secret nextauth-url google-client-id google-client-secret cloudinary-api-key cloudinary-api-secret cloudinary-name microsoft-entra-client-id microsoft-entra-client-secret microsoft-entra-issuer admin-emails; do
  grant_secret_access $secret "serviceAccount:$CLOUD_BUILD_SA" "roles/secretmanager.secretAccessor"
  grant_secret_access $secret "serviceAccount:$COMPUTE_SA" "roles/secretmanager.secretAccessor"
  grant_secret_access $secret "serviceAccount:$CLOUD_RUN_SA" "roles/secretmanager.secretAccessor"
done

# Grant Cloud SQL roles to Cloud Run service account
echo "🗄️ Granting Cloud SQL access..."

# Function to grant Cloud SQL permission if not already granted
grant_cloudsql_permission() {
  local role=$1
  local description=$2
  
  EXISTING_BINDING=$(gcloud projects get-iam-policy $PROJECT_ID --format="value(bindings[?role=='$role'].members[])" 2>/dev/null | grep -c "serviceAccount:$CLOUD_RUN_SA" || echo "0")
  
  if [ "$EXISTING_BINDING" -eq 0 ]; then
    echo "Granting $description..."
    gcloud projects add-iam-policy-binding $PROJECT_ID \
      --member="serviceAccount:$CLOUD_RUN_SA" \
      --role="$role" >/dev/null 2>&1
  else
    echo "✅ $description already exists"
  fi
}

grant_cloudsql_permission "roles/cloudsql.client" "Cloud SQL client role"
grant_cloudsql_permission "roles/cloudsql.instanceUser" "Cloud SQL instance user role"

echo "✅ GCP setup complete!"
echo ""
echo "📝 Next steps:"
echo "1. Update the secrets with your actual values:"
echo "   gcloud secrets versions add nextauth-url --data-file=<(echo -n 'https://your-app.run.app')"
echo "   gcloud secrets versions add google-client-id --data-file=<(echo -n 'your-actual-client-id')"
echo "   gcloud secrets versions add google-client-secret --data-file=<(echo -n 'your-actual-client-secret')"
echo "   # ... repeat for other secrets"
echo ""
echo "2. Update your OAuth redirect URIs to include your Cloud Run URL"
echo ""
echo "3. Run the deployment:"
echo "   gcloud builds submit --config cloudbuild.yaml ."
echo ""
echo "💰 Cost optimization tips:"
echo "- Cloud SQL instance will cost ~$7-10/month"
echo "- Cloud Run is pay-per-request (very cheap for low traffic)"
echo "- Consider setting up budget alerts"