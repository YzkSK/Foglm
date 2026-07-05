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
