#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_SCRIPT="$SCRIPT_DIR/../setup.sh"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

test_flutter_not_installed() {
  local work_dir
  work_dir="$(mktemp -d)"
  local bin_dir="$work_dir/bin"
  mkdir -p "$bin_dir"

  local output
  if output=$(PATH="$bin_dir:/usr/bin" SETUP_REPO_ROOT="$work_dir" bash "$TARGET_SCRIPT" 2>&1); then
    fail "test_flutter_not_installed: expected non-zero exit"
  fi
  echo "$output" | grep -q "flutter command not found" || fail "test_flutter_not_installed: missing error message. Got: $output"
  rm -rf "$work_dir"
  echo "PASS: test_flutter_not_installed"
}

test_creates_dart_define_when_missing() {
  local work_dir
  work_dir="$(mktemp -d)"
  local bin_dir="$work_dir/bin"
  mkdir -p "$bin_dir"

  cat > "$bin_dir/flutter" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
  chmod +x "$bin_dir/flutter"

  cat > "$work_dir/dart_define.example.json" <<'EOF'
{
  "SUPABASE_URL": "https://xxxxxxxxxxxx.supabase.co",
  "SUPABASE_ANON_KEY": "your-publishable-key-here"
}
EOF

  PATH="$bin_dir:/usr/bin" SETUP_REPO_ROOT="$work_dir" bash "$TARGET_SCRIPT" > /dev/null

  [ -f "$work_dir/dart_define.json" ] || fail "test_creates_dart_define_when_missing: dart_define.json not created"
  diff "$work_dir/dart_define.example.json" "$work_dir/dart_define.json" > /dev/null || fail "test_creates_dart_define_when_missing: dart_define.json content differs from example"

  rm -rf "$work_dir"
  echo "PASS: test_creates_dart_define_when_missing"
}

test_does_not_overwrite_existing_dart_define() {
  local work_dir
  work_dir="$(mktemp -d)"
  local bin_dir="$work_dir/bin"
  mkdir -p "$bin_dir"

  cat > "$bin_dir/flutter" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
  chmod +x "$bin_dir/flutter"

  cat > "$work_dir/dart_define.example.json" <<'EOF'
{
  "SUPABASE_URL": "https://xxxxxxxxxxxx.supabase.co",
  "SUPABASE_ANON_KEY": "your-publishable-key-here"
}
EOF

  cat > "$work_dir/dart_define.json" <<'EOF'
{
  "SUPABASE_URL": "http://127.0.0.1:54321",
  "SUPABASE_ANON_KEY": "existing-anon-key"
}
EOF

  PATH="$bin_dir:/usr/bin" SETUP_REPO_ROOT="$work_dir" bash "$TARGET_SCRIPT" > /dev/null

  grep -q '"SUPABASE_ANON_KEY": "existing-anon-key"' "$work_dir/dart_define.json" || fail "test_does_not_overwrite_existing_dart_define: dart_define.json was overwritten"

  rm -rf "$work_dir"
  echo "PASS: test_does_not_overwrite_existing_dart_define"
}

test_flutter_not_installed
test_creates_dart_define_when_missing
test_does_not_overwrite_existing_dart_define

echo "All tests passed."
