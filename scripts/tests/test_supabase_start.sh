#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_SCRIPT="$SCRIPT_DIR/../supabase-start.sh"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

# ENVIRONMENT ASSUMPTION: Tests set PATH="$bin_dir:/usr/bin" to ensure test stubs (docker/npx)
# are found first, while keeping /usr/bin in PATH so bash/grep/mktemp remain available.
# This assumes /usr/bin does NOT contain real docker/npx binaries on the test machine.
# This assumption may fail on systems where Docker is installed system-wide (e.g. Linux with apt).

test_docker_not_installed() {
  local work_dir
  work_dir="$(mktemp -d)"
  local bin_dir="$work_dir/bin"
  mkdir -p "$bin_dir"

  local output
  if output=$(PATH="$bin_dir:/usr/bin" SUPABASE_START_REPO_ROOT="$work_dir" bash "$TARGET_SCRIPT" 2>&1); then
    fail "test_docker_not_installed: expected non-zero exit"
  fi
  echo "$output" | grep -q "Docker command not found" || fail "test_docker_not_installed: missing error message. Got: $output"
  rm -rf "$work_dir"
  echo "PASS: test_docker_not_installed"
}

test_docker_not_running() {
  local work_dir
  work_dir="$(mktemp -d)"
  local bin_dir="$work_dir/bin"
  mkdir -p "$bin_dir"

  cat > "$bin_dir/docker" <<'EOF'
#!/usr/bin/env bash
if [ "$1" = "info" ]; then
  exit 1
fi
exit 0
EOF
  chmod +x "$bin_dir/docker"

  local output
  if output=$(PATH="$bin_dir:/usr/bin" SUPABASE_START_REPO_ROOT="$work_dir" bash "$TARGET_SCRIPT" 2>&1); then
    fail "test_docker_not_running: expected non-zero exit"
  fi
  echo "$output" | grep -q "Docker is not running" || fail "test_docker_not_running: missing error message. Got: $output"
  rm -rf "$work_dir"
  echo "PASS: test_docker_not_running"
}

test_docker_running_starts_supabase() {
  local work_dir
  work_dir="$(mktemp -d)"
  local bin_dir="$work_dir/bin"
  local call_log="$work_dir/npx_calls.log"
  mkdir -p "$bin_dir"

  cat > "$bin_dir/docker" <<'EOF'
#!/usr/bin/env bash
if [ "$1" = "info" ]; then
  exit 0
fi
exit 0
EOF
  chmod +x "$bin_dir/docker"

  cat > "$bin_dir/npx" <<EOF
#!/usr/bin/env bash
echo "\$@" >> "$call_log"
exit 0
EOF
  chmod +x "$bin_dir/npx"

  PATH="$bin_dir:/usr/bin" SUPABASE_START_REPO_ROOT="$work_dir" bash "$TARGET_SCRIPT" > /dev/null

  grep -q "supabase start" "$call_log" || fail "test_docker_running_starts_supabase: 'supabase start' was not called"
  grep -q "supabase db reset" "$call_log" || fail "test_docker_running_starts_supabase: 'supabase db reset' was not called"

  rm -rf "$work_dir"
  echo "PASS: test_docker_running_starts_supabase"
}

test_docker_not_installed
test_docker_not_running
test_docker_running_starts_supabase

echo "All tests passed."
