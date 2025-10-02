# GCP Deployment Guide for Workplacify

This guide will help you deploy your Workplacify app to Google Cloud Platform with cost optimization for low traffic applications.

## Architecture Overview

- **Cloud Run**: Serverless container platform (pay-per-request)
- **Cloud SQL**: Managed PostgreSQL database (db-f1-micro instance)
- **Secret Manager**: Secure environment variable storage
- **Cloud Build**: Automated CI/CD pipeline
- **Container Registry**: Docker image storage

## Cost Estimation (Monthly)

- Cloud SQL (db-f1-micro): ~$7-10
- Cloud Run: ~$0-5 (very low for minimal traffic)
- Secret Manager: ~$0.06 per secret per month
- **Total estimated cost: $10-20/month for low traffic**

## Prerequisites

1. GCP account with billing enabled
2. `gcloud` CLI installed and authenticated
3. Docker installed locally (for testing)

## Step-by-Step Deployment

### 1. Initial GCP Setup

```bash
# Make the setup script executable
chmod +x deploy/setup-gcp.sh

# Run the setup (replace with your actual project ID)
./deploy/setup-gcp.sh your-project-id
```

This script will:
- Enable required GCP APIs
- Create Cloud SQL PostgreSQL instance
- Create database and user
- Set up Secret Manager secrets
- Configure IAM permissions

### 2. Update Secrets with Real Values

```bash
# Make the update script executable
chmod +x deploy/update-secrets.sh

# Update secrets with your actual values
./deploy/update-secrets.sh your-project-id
```

You'll need to provide:
- Google OAuth credentials
- Cloudinary API credentials
- Microsoft Entra ID credentials
- Admin email addresses

### 3. Update OAuth Redirect URIs

After deployment, you'll get a Cloud Run URL. Update your OAuth providers:

**Google Cloud Console:**
- Go to APIs & Services > Credentials
- Edit your OAuth 2.0 client
- Add `https://your-cloud-run-url.run.app/api/auth/callback/google`

**Microsoft Entra ID:**
- Go to Azure Portal > App registrations
- Edit your app registration
- Add `https://your-cloud-run-url.run.app/api/auth/callback/microsoft-entra-id`

### 4. Deploy the Application

```bash
# Deploy using Cloud Build
gcloud builds submit --config cloudbuild.yaml .
```

This will:
- Build the Docker image
- Run database migrations
- Deploy to Cloud Run

### 5. Set Up Custom Domain (Optional)

```bash
# Map a custom domain to Cloud Run
gcloud run domain-mappings create --service workplacify-app --domain your-domain.com --region us-central1
```

## Environment Variables

All sensitive environment variables are stored in GCP Secret Manager:

- `database-url`: PostgreSQL connection string
- `nextauth-secret`: NextAuth.js secret key
- `google-client-id` & `google-client-secret`: Google OAuth
- `cloudinary-*`: Cloudinary configuration
- `microsoft-entra-*`: Microsoft Entra ID configuration
- `admin-emails`: Admin email addresses

## Database Management

### Running Migrations

Migrations run automatically during deployment. To run manually:

```bash
# Execute migration job
gcloud run jobs execute migration-job --region=us-central1 --wait
```

### Accessing the Database

```bash
# Connect to Cloud SQL instance
gcloud sql connect workplacify-db --user=workplacify_user --database=workplacify
```

### Database Backups

Automatic backups are configured daily at 3:00 AM UTC.

## Monitoring and Logs

```bash
# View Cloud Run logs
gcloud run services logs read workplacify-app --region=us-central1

# View Cloud Build logs
gcloud builds log BUILD_ID
```

## Cost Optimization Tips

1. **Cloud Run Configuration:**
   - Min instances: 0 (scales to zero when not in use)
   - Max instances: 10 (adjust based on expected traffic)
   - CPU: 1 vCPU (sufficient for most workloads)
   - Memory: 512Mi (can be increased if needed)

2. **Cloud SQL:**
   - Using db-f1-micro (cheapest option)
   - 10GB storage with auto-increase
   - Automated backups during low-usage hours

3. **Monitoring:**
   - Set up budget alerts in GCP Console
   - Monitor usage in Cloud Console

## Troubleshooting

### Common Issues

1. **Build Failures:**
   ```bash
   # Check build logs
   gcloud builds list --limit=5
   gcloud builds log BUILD_ID
   ```

2. **Database Connection Issues:**
   - Verify Cloud SQL instance is running
   - Check Secret Manager for correct DATABASE_URL
   - Ensure Cloud Run service account has cloudsql.client role

3. **Authentication Issues:**
   - Verify OAuth redirect URIs are updated
   - Check Secret Manager for correct OAuth credentials
   - Ensure NEXTAUTH_URL matches your Cloud Run URL

### Useful Commands

```bash
# Check Cloud Run service status
gcloud run services describe workplacify-app --region=us-central1

# Update Cloud Run service
gcloud run services update workplacify-app --region=us-central1 --memory=1Gi

# View Secret Manager secrets
gcloud secrets list

# Update a secret
echo -n "new-value" | gcloud secrets versions add secret-name --data-file=-
```

## Security Best Practices

1. All secrets stored in Secret Manager (not in code)
2. Cloud Run service uses dedicated service account
3. Database user has minimal required permissions
4. HTTPS enforced by default on Cloud Run
5. Regular security updates through automated builds

## Scaling Considerations

- Cloud Run automatically scales based on traffic
- Database can be upgraded to larger instances as needed
- Consider Cloud CDN for static assets if traffic grows
- Monitor performance and adjust resources accordingly