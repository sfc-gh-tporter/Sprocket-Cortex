#!/usr/bin/env bash
# Run Sprocket frontend stack locally
# Usage: ./scripts/dev.sh

set -e

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
NVM_DIR="$HOME/.nvm"

# Load nvm if available
[ -s "$NVM_DIR/nvm.sh" ] && source "$NVM_DIR/nvm.sh"

echo "🔧 Installing dependencies..."
(cd "$ROOT/frontend" && npm install --silent)
(cd "$ROOT/backend"  && npm install --silent)

echo "🚀 Starting backend (port 3001) and frontend (port 5173)..."
echo "   Open http://localhost:5173 in your browser."
echo "   First API call will open a browser tab for Snowflake SSO login."
echo ""

# Start backend in background
(cd "$ROOT/backend" && npx ts-node-dev --respawn --transpile-only src/index.ts &)

# Start frontend (blocking)
(cd "$ROOT/frontend" && npm run dev)
