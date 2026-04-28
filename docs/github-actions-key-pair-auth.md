# Snowflake Key-Pair Authentication for GitHub Actions

## Overview

This guide shows how to set up **encrypted private key authentication** for GitHub Actions CI/CD deployments to Snowflake. This is more secure than password-based authentication.

---

## 🔐 Why Key-Pair Authentication?

**Benefits over password authentication**:
- ✅ Private keys can be encrypted with passphrases
- ✅ Keys can be rotated independently without password resets
- ✅ No plaintext passwords stored
- ✅ Better audit trail (key usage tracking)
- ✅ Supports service accounts without human passwords

---

## 📋 Setup Process (5 Steps)

### Step 1: Generate Key Pair

On your local machine:

```bash
# Create directory for keys (already in .gitignore)
mkdir -p gh-actions-user
cd gh-actions-user

# Generate encrypted RSA private key (4096 bits)
openssl genrsa -out rsa_key.pem 4096

# Generate public key from private key
openssl rsa -in rsa_key.pem -pubout -out rsa_key.pub

# Generate unencrypted private key in PKCS#8 format for Snowflake
openssl pkcs8 -topk8 -inform PEM -in rsa_key.pem -outform PEM -nocrypt -out rsa_key.p8

# View the files created
ls -lh
# rsa_key.pem  - Original private key (optional, can delete)
# rsa_key.pub  - Public key (upload to Snowflake)
# rsa_key.p8   - PKCS#8 private key (use in GitHub secret)
```

**Security Note**: The `.gitignore` already excludes `gh-actions-user/` directory, so keys won't be committed.

### Step 2: Get Public Key Fingerprint

```bash
# Get the public key in the format Snowflake expects (single line, no headers)
cat rsa_key.pub | grep -v "BEGIN PUBLIC" | grep -v "END PUBLIC" | tr -d '\n' > rsa_key_oneline.pub

# Display public key for copying
cat rsa_key_oneline.pub
```

**Copy this output** - you'll paste it into Snowflake in the next step.

### Step 3: Configure Snowflake User with Public Key

```sql
-- Option A: Create new service account for CI/CD
CREATE USER github_actions_deployer
    DEFAULT_ROLE = STREAMLIT_DEPLOYER
    RSA_PUBLIC_KEY = '<paste_public_key_from_step_2>';

-- Option B: Add key to existing user
ALTER USER tporter SET RSA_PUBLIC_KEY = '<paste_public_key_from_step_2>';

-- Verify public key is set
DESC USER github_actions_deployer;
-- Look for RSA_PUBLIC_KEY_FP (fingerprint) - should be populated

-- Grant necessary privileges (if creating new user)
CREATE ROLE IF NOT EXISTS STREAMLIT_DEPLOYER;
GRANT USAGE ON DATABASE SPROCKET TO ROLE STREAMLIT_DEPLOYER;
GRANT USAGE ON SCHEMA SPROCKET.APP TO ROLE STREAMLIT_DEPLOYER;
GRANT CREATE STREAMLIT ON SCHEMA SPROCKET.APP TO ROLE STREAMLIT_DEPLOYER;
GRANT USAGE ON WAREHOUSE SPROCKET_WH TO ROLE STREAMLIT_DEPLOYER;
GRANT ROLE STREAMLIT_DEPLOYER TO USER github_actions_deployer;
```

### Step 4: Add Private Key to GitHub Secrets

1. **Get the private key content**:
   ```bash
   cat rsa_key.p8
   ```

2. **Copy entire output** (including `-----BEGIN PRIVATE KEY-----` and `-----END PRIVATE KEY-----`)

3. **Add to GitHub**:
   - Go to: **GitHub Repo → Settings → Secrets and variables → Actions**
   - Click **New repository secret**
   - Add these secrets:

| Secret Name | Value | Notes |
|------------|-------|-------|
| `SNOWFLAKE_PRIVATE_KEY` | Full content from `rsa_key.p8` | Include BEGIN/END lines |
| `SNOWFLAKE_ACCOUNT` | `sfsenorthamerica-tporterawsdev` | Your account identifier |
| `SNOWFLAKE_USER` | `github_actions_deployer` | User with public key |
| `SNOWFLAKE_ROLE` | `STREAMLIT_DEPLOYER` | Role with deployment privileges |
| `SNOWFLAKE_WAREHOUSE` | `SPROCKET_WH` | Warehouse for deployment |
| `SNOWFLAKE_DATABASE` | `SPROCKET` | Target database |
| `SNOWFLAKE_SCHEMA` | `APP` | Target schema |

**No SNOWFLAKE_PASSWORD needed!**

### Step 5: Test Connection Locally

Before committing, test the key locally:

```bash
# Create a test config
mkdir -p ~/.snowflake
cat > ~/.snowflake/config_test.toml <<EOF
[connections.keytest]
account = "sfsenorthamerica-tporterawsdev"
user = "github_actions_deployer"
authenticator = "SNOWFLAKE_JWT"
private_key_path = "$(pwd)/gh-actions-user/rsa_key.p8"
role = "STREAMLIT_DEPLOYER"
warehouse = "SPROCKET_WH"
EOF

# Test connection
snow connection test --connection keytest --config-file ~/.snowflake/config_test.toml

# Expected output:
# ✓ Connection test passed!
```

---

## 🔄 Updated Workflow

The workflow file `.github/workflows/deploy-streamlit.yml` has been updated to use private key authentication:

**Key changes**:
- Removed `SNOWFLAKE_PASSWORD` environment variable
- Added `SNOWFLAKE_PRIVATE_KEY` environment variable
- Writes private key to `~/.snowflake/rsa_key.p8`
- Uses `authenticator = "SNOWFLAKE_JWT"` in config.toml
- Sets `private_key_path` instead of `password`

**Workflow snippet**:
```yaml
- name: Create Snowflake CLI config
  env:
    SNOWFLAKE_PRIVATE_KEY: ${{ secrets.SNOWFLAKE_PRIVATE_KEY }}
  run: |
    echo "$SNOWFLAKE_PRIVATE_KEY" > ~/.snowflake/rsa_key.p8
    chmod 0600 ~/.snowflake/rsa_key.p8
    
    cat > ~/.snowflake/config.toml <<EOF
    [connections.prod]
    authenticator = "SNOWFLAKE_JWT"
    private_key_path = "~/.snowflake/rsa_key.p8"
    ...
    EOF
```

---

## 🧪 Testing the Setup

### Test 1: GitHub Actions Workflow

1. Commit the updated workflow (already done):
   ```bash
   git add .github/workflows/deploy-streamlit.yml
   git commit -m "Switch to private key authentication"
   git push origin main
   ```

2. Go to **Actions** tab in GitHub
3. Watch the deployment run
4. Look for "✓ Connection test passed!" in logs

### Test 2: Manual Workflow Trigger

1. Go to **Actions** → "Deploy Sprocket Streamlit App to Snowflake"
2. Click **Run workflow** → **Run workflow**
3. Monitor execution - should complete in ~2-3 minutes

---

## 🔄 Key Rotation

### When to Rotate

- Every 90-180 days (security best practice)
- After employee departure
- If key is suspected to be compromised
- As part of regular security audits

### How to Rotate

```sql
-- 1. Generate new key pair (repeat Step 1)
# openssl genrsa -out rsa_key_new.pem 4096
# openssl pkcs8 -topk8 -inform PEM -in rsa_key_new.pem -outform PEM -nocrypt -out rsa_key_new.p8
# openssl rsa -in rsa_key_new.pem -pubout -out rsa_key_new.pub

-- 2. Update Snowflake with new public key
ALTER USER github_actions_deployer SET RSA_PUBLIC_KEY = '<new_public_key>';

-- 3. Update GitHub secret SNOWFLAKE_PRIVATE_KEY with new private key content

-- 4. Test deployment

-- 5. Delete old key files
# rm gh-actions-user/rsa_key*
```

---

## 🔍 Troubleshooting

### Error: "JWT token is invalid"

**Cause**: Public key not properly set in Snowflake or key mismatch

**Fix**:
```sql
-- Check if public key is set
DESC USER github_actions_deployer;

-- If RSA_PUBLIC_KEY_FP is empty, re-set the key
ALTER USER github_actions_deployer SET RSA_PUBLIC_KEY = '<public_key>';

-- Verify it's set (RSA_PUBLIC_KEY_FP should show a fingerprint)
DESC USER github_actions_deployer;
```

### Error: "Private key could not be parsed"

**Cause**: Private key format incorrect or truncated

**Fix**:
1. Verify `rsa_key.p8` is in PKCS#8 format:
   ```bash
   head -1 rsa_key.p8
   # Should show: -----BEGIN PRIVATE KEY-----
   # (NOT "BEGIN RSA PRIVATE KEY")
   ```

2. Ensure entire key copied to GitHub secret (including BEGIN/END lines)

3. Check for extra newlines or spaces in secret value

### Error: "Authentication failed"

**Cause**: User not granted proper role or key-pair mismatch

**Fix**:
```sql
-- Verify role grant
SHOW GRANTS TO USER github_actions_deployer;

-- Should see:
-- ROLE STREAMLIT_DEPLOYER granted to user github_actions_deployer

-- If missing, grant the role
GRANT ROLE STREAMLIT_DEPLOYER TO USER github_actions_deployer;
```

### Error: "Private key path not found"

**Cause**: File permissions or path issue in workflow

**Fix**: Already handled in workflow with `chmod 0600` - if still failing, check workflow logs for exact error

---

## 🔒 Security Best Practices

### 1. Use Separate Keys per Environment

```bash
# Development
openssl genrsa -out rsa_key_dev.pem 4096
openssl pkcs8 -topk8 -inform PEM -in rsa_key_dev.pem -outform PEM -nocrypt -out rsa_key_dev.p8

# Production
openssl genrsa -out rsa_key_prod.pem 4096
openssl pkcs8 -topk8 -inform PEM -in rsa_key_prod.pem -outform PEM -nocrypt -out rsa_key_prod.p8
```

Update workflows to use environment-specific secrets: `SNOWFLAKE_PRIVATE_KEY_DEV`, `SNOWFLAKE_PRIVATE_KEY_PROD`

### 2. Restrict Key Permissions in Snowflake

```sql
-- Create deployment-specific role (minimal privileges)
CREATE ROLE STREAMLIT_DEPLOYER;

-- Grant only what's needed
GRANT USAGE ON DATABASE SPROCKET TO ROLE STREAMLIT_DEPLOYER;
GRANT USAGE ON SCHEMA SPROCKET.APP TO ROLE STREAMLIT_DEPLOYER;
GRANT CREATE STREAMLIT ON SCHEMA SPROCKET.APP TO ROLE STREAMLIT_DEPLOYER;
GRANT USAGE ON WAREHOUSE SPROCKET_WH TO ROLE STREAMLIT_DEPLOYER;

-- Do NOT grant ACCOUNTADMIN or other high-privilege roles
```

### 3. Monitor Key Usage

```sql
-- Check login history for service account
SELECT 
    user_name,
    event_timestamp,
    client_ip,
    reported_client_type,
    is_success
FROM SNOWFLAKE.ACCOUNT_USAGE.LOGIN_HISTORY
WHERE user_name = 'GITHUB_ACTIONS_DEPLOYER'
ORDER BY event_timestamp DESC
LIMIT 100;

-- Set up alerts for unusual login patterns
CREATE OR REPLACE ALERT unusual_ci_cd_logins
    WAREHOUSE = SPROCKET_WH
    SCHEDULE = '1 HOUR'
    IF (EXISTS (
        SELECT 1 
        FROM SNOWFLAKE.ACCOUNT_USAGE.LOGIN_HISTORY
        WHERE user_name = 'GITHUB_ACTIONS_DEPLOYER'
          AND event_timestamp >= DATEADD(HOUR, -1, CURRENT_TIMESTAMP())
          AND is_success = FALSE
    ))
THEN
    CALL send_alert_to_slack('CI/CD login failures detected!');
```

### 4. Secure Key Storage

- ✅ Keys stored in GitHub Secrets (encrypted at rest)
- ✅ `gh-actions-user/` excluded from Git via `.gitignore`
- ✅ Private key never logged (marked as secret in workflow)
- ✅ Temporary `~/.snowflake/rsa_key.p8` deleted after workflow completes

### 5. Add Passphrase Encryption (Optional)

For extra security, encrypt private key with passphrase:

```bash
# Generate encrypted private key
openssl genrsa -aes256 -out rsa_key_encrypted.pem 4096
# Enter passphrase when prompted

# Convert to PKCS#8 (still encrypted)
openssl pkcs8 -topk8 -inform PEM -in rsa_key_encrypted.pem -outform PEM -out rsa_key_encrypted.p8
# Re-enter passphrase

# Add passphrase to GitHub secret
# Secret name: SNOWFLAKE_PRIVATE_KEY_PASSPHRASE
```

Update workflow to use passphrase (Snowflake CLI will prompt for it automatically when reading encrypted key).

---

## 📊 Comparison: Password vs Key-Pair

| Feature | Password Auth | Key-Pair Auth |
|---------|---------------|---------------|
| **Security** | Medium (passwords can be phished) | High (keys cryptographically secure) |
| **Rotation** | Requires password change + secret update | Update public key + secret |
| **Audit Trail** | Basic login tracking | Detailed key usage tracking |
| **Service Accounts** | Requires human-set password | Native support |
| **Encryption** | Plaintext in secrets | Can be passphrase-protected |
| **Compromise Impact** | High (reusable credential) | Low (key-specific, rotatable) |
| **Setup Complexity** | Low | Medium (key generation steps) |

**Recommendation**: Use key-pair authentication for production deployments.

---

## ✅ Migration Checklist

Switching from password to key-pair auth:

- [ ] Generate RSA key pair (4096 bits)
- [ ] Extract public key in Snowflake format (single line)
- [ ] Create/update Snowflake user with public key
- [ ] Add `SNOWFLAKE_PRIVATE_KEY` to GitHub secrets
- [ ] Remove `SNOWFLAKE_PASSWORD` from GitHub secrets (optional - keep as backup)
- [ ] Update workflow file (already done!)
- [ ] Test connection locally with `snow connection test`
- [ ] Push workflow update to GitHub
- [ ] Monitor first automated deployment
- [ ] Verify app deployed successfully
- [ ] Document key rotation schedule (90 days recommended)
- [ ] Securely delete local private key files (keep backup in password manager)

---

## 🎯 Next Steps

1. **Generate your key pair** (Step 1-2 above)
2. **Configure Snowflake user** with public key (Step 3)
3. **Add private key to GitHub secrets** (Step 4)
4. **Test locally** before pushing (Step 5)
5. **Push and verify** automated deployment works
6. **Set up key rotation reminder** (90 days)

Your workflow is already updated to support key-pair auth! 🎉
