#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${SETUP_REPO_ROOT:-$(cd "$SCRIPT_DIR/.." && pwd)}"

if ! command -v flutter > /dev/null 2>&1; then
  echo "Error: flutter command not found. Please install Flutter and try again." >&2
  echo "https://docs.flutter.dev/get-started/install" >&2
  exit 1
fi

echo "Installing Flutter dependencies..."
(cd "$REPO_ROOT" && flutter pub get)

DART_DEFINE_FILE="$REPO_ROOT/dart_define.json"
DART_DEFINE_EXAMPLE="$REPO_ROOT/dart_define.example.json"

if [ ! -f "$DART_DEFINE_FILE" ]; then
  echo "Creating dart_define.json from dart_define.example.json..."
  cp "$DART_DEFINE_EXAMPLE" "$DART_DEFINE_FILE"
  echo "dart_define.json has been created. Fill in the actual values before running the app."
else
  echo "dart_define.json already exists. Skipping."
fi

echo ""
echo "Setup complete."
