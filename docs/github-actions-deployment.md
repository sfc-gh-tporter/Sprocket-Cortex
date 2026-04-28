# GitHub Actions CI/CD for Sprocket Streamlit App

## Overview

This guide walks through setting up automated deployment of the Sprocket Streamlit app to Snowflake using GitHub Actions.

## 📋 Prerequisites

- GitHub repository for Sprocket project
- Snowflake account with appropriate permissions (SYSADMIN or equivalent)
- Streamlit app files in `streamlit/` directory
- `snowflake.yml` deployment manifest

## 🔐 Required GitHub Secrets

Configure these secrets in your GitHub repository:

**Repository Settings → Secrets and variables → Actions → New repository secret**

| Secret Name | Description | Example Value |
|------------|-------------|---------------|
| `SNOWFLAKE_ACCOUNT` | Account identifier | `sfsenorthamerica-tporterawsdev` |
| `SNOWFLAKE_USER` | Username for deployment | `tporter` |
| `SNOWFLAKE_PASSWORD` | Password for user | `<your_password>` |
| `SNOWFLAKE_ROLE` | Role with deployment privileges | `SYSADMIN` |
| `SNOWFLAKE_WAREHOUSE` | Warehouse for deployment | `SPROCKET_WH` |
| `SNOWFLAKE_DATABASE` | Target database | `SPROCKET` |
| `SNOWFLAKE_SCHEMA` | Target schema | `APP` |

### Finding Your Account Identifier

```sql
-- Run in Snowflake to get account identifier
SELECT CURRENT_ACCOUNT_NAME();
SELECT CURRENT_ORGANIZATION_NAME();

-- Full account identifier format:
-- <org_name>-<account_name>
```

## 📁 Required Files

### 1. GitHub Actions Workflow

**Location**: `.github/workflows/deploy-streamlit.yml`

**Triggers**:
- Push to `main` branch when `streamlit/**` files change
- Manual trigger via GitHub UI (workflow_dispatch)

**Steps**:
1. Checkout code
2. Install Python 3.11
3. Install Snowflake CLI
4. Create config.toml with credentials from secrets
5. Validate Snowflake connection
6. Deploy Streamlit app with `snow streamlit deploy --replace`

### 2. Streamlit Deployment Manifest

**Location**: `streamlit/snowflake.yml`

```yaml
definition_version: 2
entities:
  streamlit_app:
    type: streamlit
    identifier:
      name: SPROCKET.APP.SPROCKET_APP
    title: "Sprocket AI"
    query_warehouse: SPROCKET_WH
    main_file: streamlit_app.py
    stage: streamlit
```

## 🚀 Setup Instructions

### Step 1: Add GitHub Secrets

1. Go to your GitHub repository
2. Click **Settings** → **Secrets and variables** → **Actions**
3. Click **New repository secret**
4. Add each secret from the table above
5. Click **Add secret** for each

### Step 2: Commit Workflow File

```bash
# From project root
git add .github/workflows/deploy-streamlit.yml
git commit -m "Add GitHub Actions workflow for Streamlit deployment"
git push origin main
```

### Step 3: Verify Workflow

1. Go to **Actions** tab in GitHub repository
2. You should see "Deploy Sprocket Streamlit App to Snowflake" workflow
3. Click on the workflow run to see execution logs
4. Wait for green checkmark (✅) indicating success

### Step 4: Test Manual Deployment

1. Go to **Actions** tab
2. Select "Deploy Sprocket Streamlit App to Snowflake"
3. Click **Run workflow** → **Run workflow**
4. Monitor execution in real-time

## 📊 Workflow Behavior

### Automatic Deployment

**Triggers when**:
- Any file in `streamlit/` directory changes
- Workflow file itself changes
- Changes pushed to `main` branch

**Does NOT trigger when**:
- Changes to other directories (`sql/`, `docs/`, `evals/`)
- Push to other branches (`dev`, `feature/*`)

### Environment

**Production environment**:
- Uses `production` environment in GitHub Actions
- Can add protection rules (required reviewers, wait timers)
- Tracks deployment history

## 🔍 Troubleshooting

### Error: "Invalid connection configuration"

**Cause**: Missing or incorrect secrets

**Fix**:
1. Verify all 7 secrets are set in GitHub
2. Check for typos in secret values
3. Ensure account identifier format is correct (org-account)

### Error: "Permission denied"

**Cause**: User/role lacks privileges

**Fix**:
```sql
-- Grant necessary privileges to deployment role
GRANT USAGE ON DATABASE SPROCKET TO ROLE SYSADMIN;
GRANT USAGE ON SCHEMA SPROCKET.APP TO ROLE SYSADMIN;
GRANT CREATE STREAMLIT ON SCHEMA SPROCKET.APP TO ROLE SYSADMIN;
GRANT USAGE ON WAREHOUSE SPROCKET_WH TO ROLE SYSADMIN;
```

### Error: "snowflake.yml not found"

**Cause**: Working directory mismatch

**Fix**: Workflow already sets `WORKING_DIRECTORY: './streamlit'` - ensure `snowflake.yml` exists at `streamlit/snowflake.yml`

### Error: "App name conflict"

**Cause**: App already exists, `--replace` flag not working

**Fix**:
```sql
-- Manually drop app if needed
DROP STREAMLIT SPROCKET.APP.SPROCKET_APP;

-- Re-run workflow
```

## 🔐 Security Best Practices

### 1. Use Service Account

Instead of personal credentials, create a dedicated service account:

```sql
-- Create service user for CI/CD
CREATE USER github_actions_deployer
    PASSWORD = '<strong_password>'
    DEFAULT_ROLE = STREAMLIT_DEPLOYER
    MUST_CHANGE_PASSWORD = FALSE;

-- Create deployment role
CREATE ROLE STREAMLIT_DEPLOYER;

-- Grant minimal privileges
GRANT USAGE ON DATABASE SPROCKET TO ROLE STREAMLIT_DEPLOYER;
GRANT USAGE ON SCHEMA SPROCKET.APP TO ROLE STREAMLIT_DEPLOYER;
GRANT CREATE STREAMLIT ON SCHEMA SPROCKET.APP TO ROLE STREAMLIT_DEPLOYER;
GRANT USAGE ON WAREHOUSE SPROCKET_WH TO ROLE STREAMLIT_DEPLOYER;

-- Assign role to user
GRANT ROLE STREAMLIT_DEPLOYER TO USER github_actions_deployer;
```

Update GitHub secrets:
- `SNOWFLAKE_USER`: `github_actions_deployer`
- `SNOWFLAKE_PASSWORD`: `<service_account_password>`
- `SNOWFLAKE_ROLE`: `STREAMLIT_DEPLOYER`

### 2. Rotate Credentials Regularly

- Update `SNOWFLAKE_PASSWORD` secret every 90 days
- Use GitHub's secret rotation reminders

### 3. Use Environment Protection Rules

In GitHub repository:
1. Settings → Environments → production
2. Add required reviewers for production deployments
3. Set deployment branch restrictions (main only)

## 📈 Deployment Monitoring

### View Deployment History

**GitHub UI**:
- Actions tab → Deploy Sprocket Streamlit App → Runs
- Shows: Date, commit, duration, status

**Snowflake**:
```sql
-- View app metadata
DESCRIBE STREAMLIT SPROCKET.APP.SPROCKET_APP;

-- Check last modified timestamp
SHOW STREAMLIT APPS IN SCHEMA SPROCKET.APP;
```

### Set Up Notifications

**GitHub**:
1. Settings → Notifications → Actions
2. Enable email notifications for workflow failures

**Slack** (optional):
Add to workflow:
```yaml
- name: Notify on failure
  if: failure()
  uses: slackapi/slack-github-action@v1
  with:
    webhook-url: ${{ secrets.SLACK_WEBHOOK }}
    payload: |
      {
        "text": "❌ Sprocket Streamlit deployment failed!"
      }
```

## 🎯 Next Steps

### Multi-Environment Deployment

Extend workflow to support dev/staging/prod:

```yaml
strategy:
  matrix:
    environment: [dev, staging, prod]
    include:
      - environment: dev
        branch: develop
      - environment: staging
        branch: staging
      - environment: prod
        branch: main
```

### Pre-Deployment Testing

Add validation steps before deployment:

```yaml
- name: Run pre-deployment tests
  run: |
    cd streamlit
    python -m pytest tests/
    python -m pylint streamlit_app.py
```

### Deployment Approval

Require manual approval for production:

```yaml
jobs:
  deploy-streamlit:
    environment: 
      name: production
      url: https://app.snowflake.com/...
    # Requires approval in GitHub UI
```

## 📚 References

- [Snowflake Streamlit CI/CD Docs](https://docs.snowflake.com/en/developer-guide/streamlit/app-development/creating-your-app#set-up-ci-cd-with-github-actions)
- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Snowflake CLI Reference](https://docs.snowflake.com/en/developer-guide/snowflake-cli/reference)

---

## ✅ Checklist

Before going live, verify:

- [ ] All 7 GitHub secrets configured
- [ ] Service account created with minimal privileges
- [ ] Workflow file committed to `main` branch
- [ ] Manual test deployment successful
- [ ] Streamlit app accessible in Snowsight
- [ ] Deployment notifications configured
- [ ] Protection rules set for production environment
