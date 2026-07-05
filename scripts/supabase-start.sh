#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${SUPABASE_START_REPO_ROOT:-$(cd "$SCRIPT_DIR/.." && pwd)}"

if ! command -v docker > /dev/null 2>&1; then
  echo "Error: Docker command not found. Please install Docker Desktop and try again." >&2
  exit 1
fi

if ! docker info > /dev/null 2>&1; then
  echo "Error: Docker is not running. Please start Docker Desktop and try again." >&2
  exit 1
fi

echo "Starting local Supabase environment (this may take a while on first run)..."
npx supabase start

echo "Applying migrations..."
npx supabase db reset

DART_DEFINE_FILE="$REPO_ROOT/dart_define.json"
DART_DEFINE_EXAMPLE="$REPO_ROOT/dart_define.example.json"

if [ ! -f "$DART_DEFINE_FILE" ]; then
  echo "Creating dart_define.json from dart_define.example.json..."
  cp "$DART_DEFINE_EXAMPLE" "$DART_DEFINE_FILE"
fi

STATUS_OUTPUT="$(npx supabase status)"

API_URL="$(echo "$STATUS_OUTPUT" | grep -i -E '^[[:space:]]*API URL' | head -n1 | sed -E 's/^[^:]*:[[:space:]]*//' || true)"
ANON_KEY="$(echo "$STATUS_OUTPUT" | grep -i -E '^[[:space:]]*anon key' | head -n1 | sed -E 's/^[^:]*:[[:space:]]*//' || true)"

if [ -z "$API_URL" ] || [ -z "$ANON_KEY" ]; then
  echo "Error: failed to parse 'supabase status' output. dart_define.json was not updated." >&2
  exit 1
fi

sed -i.bak -E \
  -e "s#(\"SUPABASE_URL\"[[:space:]]*:[[:space:]]*)\"[^\"]*\"#\1\"$API_URL\"#" \
  -e "s#(\"SUPABASE_ANON_KEY\"[[:space:]]*:[[:space:]]*)\"[^\"]*\"#\1\"$ANON_KEY\"#" \
  "$DART_DEFINE_FILE"
rm -f "$DART_DEFINE_FILE.bak"

echo ""
echo "Local Supabase environment is ready."
echo "  API URL: $API_URL"
echo "dart_define.json has been updated with the local anon key."
