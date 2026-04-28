#!/bin/bash
# Test Snowflake key-pair authentication without creating a permanent connection
# Run this script to validate your key pair works before setting up GitHub Actions

set -e

echo "🔑 Testing Snowflake Key-Pair Authentication"
echo "============================================"
echo ""

# Configuration (update these values)
ACCOUNT="sfsenorthamerica-tporterawsdev"
USER="github_actions_deployer"  # Service account for CI/CD
ROLE="STREAMLIT_DEPLOYER"
WAREHOUSE="SPROCKET_WH"
DATABASE="SPROCKET"
SCHEMA="APP"

# Check if key pair exists
if [ ! -f "gh-actions-user/rsa_key.p8" ]; then
    echo "❌ Private key not found at gh-actions-user/rsa_key.p8"
    echo ""
    echo "Generate key pair first:"
    echo "  mkdir -p gh-actions-user && cd gh-actions-user"
    echo "  openssl genrsa -out rsa_key.pem 4096"
    echo "  openssl pkcs8 -topk8 -inform PEM -in rsa_key.pem -outform PEM -nocrypt -out rsa_key.p8"
    echo "  openssl rsa -in rsa_key.pem -pubout -out rsa_key.pub"
    echo "  cat rsa_key.pub | grep -v 'BEGIN PUBLIC' | grep -v 'END PUBLIC' | tr -d '\n'"
    echo ""
    echo "Then set the public key in Snowflake:"
    echo "  ALTER USER $USER SET RSA_PUBLIC_KEY = '<your_public_key>';"
    exit 1
fi

echo "✓ Found private key at gh-actions-user/rsa_key.p8"
echo ""

# Create temporary config file (won't touch ~/.snowflake/config.toml)
TEMP_CONFIG=$(mktemp /tmp/snow_test_config.XXXXXX.toml)
trap "rm -f $TEMP_CONFIG" EXIT

cat > "$TEMP_CONFIG" <<EOF
[connections.test]
account = "$ACCOUNT"
user = "$USER"
authenticator = "SNOWFLAKE_JWT"
private_key_path = "$(pwd)/gh-actions-user/rsa_key.p8"
role = "$ROLE"
warehouse = "$WAREHOUSE"
database = "$DATABASE"
schema = "$SCHEMA"
EOF

echo "📝 Created temporary config at: $TEMP_CONFIG"
echo ""

# Test connection
echo "🔌 Testing connection with key-pair authentication..."
echo ""

if snow connection test --connection test --config-file "$TEMP_CONFIG"; then
    echo ""
    echo "✅ SUCCESS! Key-pair authentication works!"
    echo ""
    echo "Next steps:"
    echo "1. Add SNOWFLAKE_PRIVATE_KEY to GitHub secrets:"
    echo "   cat gh-actions-user/rsa_key.p8"
    echo ""
    echo "2. Update these GitHub secrets:"
    echo "   SNOWFLAKE_ACCOUNT = $ACCOUNT"
    echo "   SNOWFLAKE_USER = $USER"
    echo "   SNOWFLAKE_ROLE = $ROLE"
    echo "   SNOWFLAKE_WAREHOUSE = $WAREHOUSE"
    echo "   SNOWFLAKE_DATABASE = $DATABASE"
    echo "   SNOWFLAKE_SCHEMA = $SCHEMA"
    echo ""
    echo "3. Push the updated workflow to trigger deployment"
else
    echo ""
    echo "❌ FAILED! Connection test did not pass."
    echo ""
    echo "Troubleshooting:"
    echo "1. Verify public key is set in Snowflake:"
    echo "   DESC USER $USER;"
    echo "   -- Look for RSA_PUBLIC_KEY_FP (should be populated)"
    echo ""
    echo "2. If RSA_PUBLIC_KEY_FP is empty, set the public key:"
    echo "   cat gh-actions-user/rsa_key.pub | grep -v 'BEGIN PUBLIC' | grep -v 'END PUBLIC' | tr -d '\n'"
    echo "   -- Copy output and run:"
    echo "   ALTER USER $USER SET RSA_PUBLIC_KEY = '<paste_public_key>';"
    echo ""
    echo "3. Verify role and warehouse access:"
    echo "   SHOW GRANTS TO USER $USER;"
    exit 1
fi

# Optional: Test a simple query
echo "📊 Testing simple query..."
if snow sql -q "SELECT CURRENT_USER(), CURRENT_ROLE(), CURRENT_WAREHOUSE()" --connection test --config-file "$TEMP_CONFIG"; then
    echo ""
    echo "🎉 All tests passed! You're ready to deploy via GitHub Actions."
else
    echo ""
    echo "⚠️  Connection test passed but query failed. Check warehouse/role permissions."
fi
