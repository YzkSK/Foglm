#!/usr/bin/env bash
set -euo pipefail

echo "Stopping local Supabase environment..."
npx supabase stop
