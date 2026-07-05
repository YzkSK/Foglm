#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_SCRIPT="$SCRIPT_DIR/../supabase-stop.sh"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

test_calls_supabase_stop() {
  local work_dir
  work_dir="$(mktemp -d)"
  local bin_dir="$work_dir/bin"
  local call_log="$work_dir/npx_calls.log"
  mkdir -p "$bin_dir"

  cat > "$bin_dir/npx" <<EOF
#!/usr/bin/env bash
echo "\$@" >> "$call_log"
exit 0
EOF
  chmod +x "$bin_dir/npx"

  PATH="$bin_dir:$PATH" bash "$TARGET_SCRIPT" > /dev/null

  grep -q "supabase stop" "$call_log" || fail "test_calls_supabase_stop: npx was not called with 'supabase stop'"

  rm -rf "$work_dir"
  echo "PASS: test_calls_supabase_stop"
}

test_calls_supabase_stop

echo "All tests passed."
