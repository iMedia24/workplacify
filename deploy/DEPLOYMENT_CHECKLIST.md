# Workplacify GCP Deployment Checklist

Use this checklist to ensure a smooth deployment to Google Cloud Platform.

## Pre-Deployment Checklist

### 1. GCP Account Setup
- [ ] GCP account created and billing enabled
- [ ] `gcloud` CLI installed and authenticated
- [ ] Project created in GCP Console
- [ ] Project ID noted for deployment scripts

### 2. Environment Variables Collection
Gather all required credentials before starting:

- [ ] **Google OAuth**
  - [ ] Google Cloud Console project created
  - [ ] OAuth 2.0 credentials created
  - [ ] Client ID and Client Secret obtained

- [ ] **Microsoft Entra ID** (if using)
  - [ ] Azure AD app registration created
  - [ ] Client ID, Client Secret, and Issuer URL obtained

- [ ] **Cloudinary**
  - [ ] Cloudinary account created
  - [ ] API Key, API Secret, and Cloud Name obtained

- [ ] **Admin Configuration**
  - [ ] Admin email addresses identified

### 3. Local Testing
- [ ] Application runs locally with `npm run dev`
- [ ] Database migrations work locally
- [ ] Authentication providers tested locally
- [ ] File uploads work with Cloudinary

## Deployment Steps

### Step 1: Initial GCP Setup
```bash
# Run the setup script
./deploy/setup-gcp.sh your-project-id
```

- [ ] Script completed without errors
- [ ] Cloud SQL instance created
- [ ] Secret Manager secrets created
- [ ] IAM permissions configured

### Step 2: Update Secrets
```bash
# Update secrets with real values
./deploy/update-secrets.sh your-project-id
```

- [ ] All secrets updated with actual values
- [ ] No placeholder values remaining

### Step 3: Deploy Application
```bash
# Deploy using Cloud Build
gcloud builds submit --config cloudbuild.yaml .
```

- [ ] Build completed successfully
- [ ] Database migrations ran successfully
- [ ] Cloud Run service deployed
- [ ] Health check endpoint responding

### Step 4: Post-Deployment Configuration

#### OAuth Redirect URIs
After deployment, get your Cloud Run URL and update:

- [ ] **Google OAuth**
  - [ ] Added `https://your-app-url.run.app/api/auth/callback/google` to authorized redirect URIs

- [ ] **Microsoft Entra ID**
  - [ ] Added `https://your-app-url.run.app/api/auth/callback/microsoft-entra-id` to redirect URIs

#### DNS Configuration (Optional)
- [ ] Custom domain configured in Cloud Run
- [ ] DNS records updated to point to Cloud Run
- [ ] SSL certificate provisioned

### Step 5: Verification

#### Application Testing
- [ ] Application loads at Cloud Run URL
- [ ] Health check endpoint returns 200: `https://your-app-url.run.app/api/trpc/healthcheck`
- [ ] Google OAuth login works
- [ ] Microsoft Entra ID login works (if configured)
- [ ] File upload functionality works
- [ ] Database operations work correctly

#### Performance Testing
```bash
# Test health check
node deploy/health-check.js https://your-app-url.run.app
```

- [ ] Health check passes
- [ ] Response time acceptable
- [ ] No errors in Cloud Run logs

## Post-Deployment Setup

### Step 6: Initial Data Setup
- [ ] Sign in to the application
- [ ] Use the organization invite code from deployment logs
- [ ] Create initial office and floor plans
- [ ] Test desk booking functionality

### Step 7: Monitoring Setup

#### Budget Alerts
```bash
# Get your billing account ID
gcloud billing accounts list

# Create budget alert (update project ID in budget-alert.yaml first)
gcloud billing budgets create --billing-account=BILLING_ACCOUNT_ID --budget-from-file=deploy/budget-alert.yaml
```

- [ ] Budget alert configured
- [ ] Notification emails set up

#### Logging and Monitoring
- [ ] Cloud Run logs accessible
- [ ] Error reporting configured
- [ ] Performance monitoring enabled

### Step 8: Security Review
- [ ] All secrets stored in Secret Manager (not in code)
- [ ] Database user has minimal permissions
- [ ] Cloud Run service uses dedicated service account
- [ ] HTTPS enforced (automatic with Cloud Run)
- [ ] No sensitive data in logs

## Ongoing Maintenance

### Regular Tasks
- [ ] Monitor costs in GCP Console
- [ ] Review Cloud Run logs for errors
- [ ] Update dependencies regularly
- [ ] Backup database (automatic with Cloud SQL)

### Scaling Considerations
- [ ] Monitor Cloud Run metrics
- [ ] Adjust CPU/memory if needed
- [ ] Consider upgrading Cloud SQL instance for growth
- [ ] Set up Cloud CDN if traffic increases

## Troubleshooting

### Common Issues and Solutions

#### Build Failures
```bash
# Check build logs
gcloud builds list --limit=5
gcloud builds log BUILD_ID
```

#### Database Connection Issues
```bash
# Check Cloud SQL instance status
gcloud sql instances describe workplacify-db

# Test database connection
gcloud sql connect workplacify-db --user=workplacify_user --database=workplacify
```

#### Authentication Issues
- Verify OAuth redirect URIs are correct
- Check Secret Manager for correct credentials
- Ensure NEXTAUTH_URL matches your domain

#### Performance Issues
```bash
# Check Cloud Run metrics
gcloud run services describe workplacify-app --region=us-central1

# View recent logs
gcloud run services logs read workplacify-app --region=us-central1 --limit=50
```

## Emergency Procedures

### Rollback Deployment
```bash
# List recent revisions
gcloud run revisions list --service=workplacify-app --region=us-central1

# Rollback to previous revision
gcloud run services update-traffic workplacify-app --to-revisions=REVISION_NAME=100 --region=us-central1
```

### Database Recovery
```bash
# List available backups
gcloud sql backups list --instance=workplacify-db

# Restore from backup (creates new instance)
gcloud sql backups restore BACKUP_ID --restore-instance=workplacify-db-restored --backup-instance=workplacify-db
```

## Cost Optimization Checklist

- [ ] Cloud Run min instances set to 0
- [ ] Cloud SQL using smallest appropriate instance (db-f1-micro)
- [ ] Budget alerts configured
- [ ] Unused resources cleaned up
- [ ] Regular cost monitoring in place

## Success Criteria

Your deployment is successful when:
- [ ] Application is accessible at the Cloud Run URL
- [ ] All authentication methods work
- [ ] Users can create organizations and book desks
- [ ] File uploads work correctly
- [ ] No errors in application logs
- [ ] Monthly costs are within expected range ($10-20)

---

**Estimated Total Deployment Time:** 30-60 minutes
**Monthly Cost Estimate:** $10-20 for low traffic applications