# Quick Test: Key-Pair Authentication (No Permanent Connection)

## 🎯 Goal

Test key-pair authentication works **without** creating a permanent connection in `~/.snowflake/config.toml`.

---

## ⚡ Quick Test (3 Steps)

### Step 1: Generate Key Pair (If Not Done Yet)

```bash
# From project root
mkdir -p gh-actions-user && cd gh-actions-user

# Generate keys
openssl genrsa -out rsa_key.pem 4096
openssl pkcs8 -topk8 -inform PEM -in rsa_key.pem -outform PEM -nocrypt -out rsa_key.p8
openssl rsa -in rsa_key.pem -pubout -out rsa_key.pub

# Get public key for Snowflake (single line, no headers)
cat rsa_key.pub | grep -v "BEGIN PUBLIC" | grep -v "END PUBLIC" | tr -d '\n'

# Copy this output ^^^
```

### Step 2: Set Public Key in Snowflake

Use your **existing user** (no need to create new one):

```sql
-- Set public key on your existing user
ALTER USER tporter SET RSA_PUBLIC_KEY = '<paste_public_key_from_step_1>';

-- Verify it's set
DESC USER tporter;
-- Look for RSA_PUBLIC_KEY_FP column - should show a fingerprint (not null)
```

### Step 3: Run Test Script

```bash
# From project root
./scripts/test_key_auth.sh
```

**What it does**:
- ✅ Checks if `gh-actions-user/rsa_key.p8` exists
- ✅ Creates a **temporary** config file (not in `~/.snowflake/`)
- ✅ Tests connection with `snow connection test`
- ✅ Runs a simple query to verify
- ✅ Cleans up temp file automatically
- ✅ Shows next steps if successful

**Expected output**:
```
🔑 Testing Snowflake Key-Pair Authentication
============================================

✓ Found private key at gh-actions-user/rsa_key.p8

📝 Created temporary config at: /tmp/snow_test_config.ABC123.toml

🔌 Testing connection with key-pair authentication...

✅ SUCCESS! Key-pair authentication works!

Next steps:
1. Add SNOWFLAKE_PRIVATE_KEY to GitHub secrets:
   cat gh-actions-user/rsa_key.p8
...
```

---

## 🔧 Manual Testing (Alternative)

If you prefer to test manually without the script:

### Option 1: Direct CLI Command

```bash
snow sql \
  --account sfsenorthamerica-tporterawsdev \
  --user tporter \
  --authenticator SNOWFLAKE_JWT \
  --private-key-path $(pwd)/gh-actions-user/rsa_key.p8 \
  --role SYSADMIN \
  --warehouse SPROCKET_WH \
  -q "SELECT CURRENT_USER(), CURRENT_ROLE()"
```

### Option 2: Temporary Config File

```bash
# Create temp config (won't touch ~/.snowflake/config.toml)
cat > /tmp/test_key.toml <<EOF
[connections.test]
account = "sfsenorthamerica-tporterawsdev"
user = "tporter"
authenticator = "SNOWFLAKE_JWT"
private_key_path = "$(pwd)/gh-actions-user/rsa_key.p8"
role = "SYSADMIN"
warehouse = "SPROCKET_WH"
EOF

# Test connection
snow connection test --connection test --config-file /tmp/test_key.toml

# Test query
snow sql -q "SELECT CURRENT_USER()" --connection test --config-file /tmp/test_key.toml

# Clean up
rm /tmp/test_key.toml
```

---

## 🚨 Troubleshooting

### Issue: "JWT token is invalid"

**Cause**: Public key not set or mismatch

**Fix**:
```sql
-- Check if key is set
DESC USER tporter;

-- If RSA_PUBLIC_KEY_FP is empty, set it again
ALTER USER tporter SET RSA_PUBLIC_KEY = '<your_public_key>';
```

### Issue: "Private key file not found"

**Cause**: Wrong path or key not generated

**Fix**:
```bash
# Verify file exists
ls -lh gh-actions-user/rsa_key.p8

# If not, generate it (see Step 1)
```

### Issue: "Unable to parse private key"

**Cause**: Wrong format (needs PKCS#8)

**Fix**:
```bash
# Check first line of key
head -1 gh-actions-user/rsa_key.p8

# Should show: -----BEGIN PRIVATE KEY-----
# If it shows "BEGIN RSA PRIVATE KEY", convert it:
openssl pkcs8 -topk8 -inform PEM -in gh-actions-user/rsa_key.pem -outform PEM -nocrypt -out gh-actions-user/rsa_key.p8
```

---

## ✅ Success Path

Once test passes:

1. **Copy private key for GitHub secret**:
   ```bash
   cat gh-actions-user/rsa_key.p8
   ```

2. **Add to GitHub**:
   - Go to: **Settings → Secrets → Actions**
   - Add secret: `SNOWFLAKE_PRIVATE_KEY` = full content (with BEGIN/END lines)
   - Update `SNOWFLAKE_USER` = `tporter` (or whatever user you tested with)

3. **Push and deploy**:
   ```bash
   git add .github/workflows/deploy-streamlit.yml
   git commit -m "Enable key-pair auth for CI/CD"
   git push origin main
   ```

4. **Monitor GitHub Actions** - should deploy successfully!

---

## 🧹 Cleanup

The test script automatically cleans up:
- ✅ Temporary config file deleted on exit
- ✅ No changes to `~/.snowflake/config.toml`
- ✅ No permanent connections created

Keys remain in `gh-actions-user/` (already in `.gitignore`).

---

## 🔐 Security Notes

- ✅ Keys stored in `gh-actions-user/` (excluded from Git)
- ✅ Temp config files use `/tmp/` (auto-cleaned)
- ✅ Private key permissions: `0600` (owner read/write only)
- ✅ No passwords involved

**After successful test**, you can securely delete local keys or keep them for rotation.
