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
if [ "\$1" = "supabase" ] && [ "\$2" = "status" ]; then
  cat <<'STATUS'
         API URL: http://127.0.0.1:54321
          DB URL: postgresql://postgres:postgres@127.0.0.1:54322/postgres
        anon key: test-local-anon-key
STATUS
fi
exit 0
EOF
  chmod +x "$bin_dir/npx"

  cat > "$work_dir/dart_define.example.json" <<'EOF'
{
  "SUPABASE_URL": "https://xxxxxxxxxxxx.supabase.co",
  "SUPABASE_ANON_KEY": "your-publishable-key-here"
}
EOF

  PATH="$bin_dir:/usr/bin" SUPABASE_START_REPO_ROOT="$work_dir" bash "$TARGET_SCRIPT" > /dev/null

  grep -q "supabase start" "$call_log" || fail "test_docker_running_starts_supabase: 'supabase start' was not called"
  grep -q "supabase db reset" "$call_log" || fail "test_docker_running_starts_supabase: 'supabase db reset' was not called"

  rm -rf "$work_dir"
  echo "PASS: test_docker_running_starts_supabase"
}

test_happy_path_updates_dart_define() {
  local work_dir
  work_dir="$(mktemp -d)"
  local bin_dir="$work_dir/bin"
  mkdir -p "$bin_dir"

  cat > "$bin_dir/docker" <<'EOF'
#!/usr/bin/env bash
if [ "$1" = "info" ]; then
  exit 0
fi
exit 0
EOF
  chmod +x "$bin_dir/docker"

  cat > "$bin_dir/npx" <<'EOF'
#!/usr/bin/env bash
if [ "$1" = "supabase" ] && [ "$2" = "status" ]; then
  cat <<'STATUS'
         API URL: http://127.0.0.1:54321
          DB URL: postgresql://postgres:postgres@127.0.0.1:54322/postgres
        anon key: test-local-anon-key
STATUS
  exit 0
fi
exit 0
EOF
  chmod +x "$bin_dir/npx"

  cat > "$work_dir/dart_define.example.json" <<'EOF'
{
  "SUPABASE_URL": "https://xxxxxxxxxxxx.supabase.co",
  "SUPABASE_ANON_KEY": "your-publishable-key-here",
  "SOME_OTHER_KEY": "unchanged-value"
}
EOF

  PATH="$bin_dir:/usr/bin" SUPABASE_START_REPO_ROOT="$work_dir" bash "$TARGET_SCRIPT" > /dev/null

  [ -f "$work_dir/dart_define.json" ] || fail "test_happy_path_updates_dart_define: dart_define.json not created"
  grep -q '"SUPABASE_URL": "http://127.0.0.1:54321"' "$work_dir/dart_define.json" || fail "test_happy_path_updates_dart_define: SUPABASE_URL not updated"
  grep -q '"SUPABASE_ANON_KEY": "test-local-anon-key"' "$work_dir/dart_define.json" || fail "test_happy_path_updates_dart_define: SUPABASE_ANON_KEY not updated"
  grep -q '"SOME_OTHER_KEY": "unchanged-value"' "$work_dir/dart_define.json" || fail "test_happy_path_updates_dart_define: SOME_OTHER_KEY was unexpectedly modified"

  rm -rf "$work_dir"
  echo "PASS: test_happy_path_updates_dart_define"
}

test_updates_existing_dart_define_in_place() {
  local work_dir
  work_dir="$(mktemp -d)"
  local bin_dir="$work_dir/bin"
  mkdir -p "$bin_dir"

  cat > "$bin_dir/docker" <<'EOF'
#!/usr/bin/env bash
if [ "$1" = "info" ]; then
  exit 0
fi
exit 0
EOF
  chmod +x "$bin_dir/docker"

  cat > "$bin_dir/npx" <<'EOF'
#!/usr/bin/env bash
if [ "$1" = "supabase" ] && [ "$2" = "status" ]; then
  cat <<'STATUS'
         API URL: http://127.0.0.1:54321
          DB URL: postgresql://postgres:postgres@127.0.0.1:54322/postgres
        anon key: test-local-anon-key
STATUS
  exit 0
fi
exit 0
EOF
  chmod +x "$bin_dir/npx"

  cat > "$work_dir/dart_define.example.json" <<'EOF'
{
  "SUPABASE_URL": "https://xxxxxxxxxxxx.supabase.co",
  "SUPABASE_ANON_KEY": "your-publishable-key-here"
}
EOF

  cat > "$work_dir/dart_define.json" <<'EOF'
{
  "SUPABASE_URL": "http://127.0.0.1:11111",
  "SUPABASE_ANON_KEY": "old-anon-key"
}
EOF

  PATH="$bin_dir:/usr/bin" SUPABASE_START_REPO_ROOT="$work_dir" bash "$TARGET_SCRIPT" > /dev/null

  grep -q '"SUPABASE_URL": "http://127.0.0.1:54321"' "$work_dir/dart_define.json" || fail "test_updates_existing_dart_define_in_place: SUPABASE_URL not updated"
  grep -q '"SUPABASE_ANON_KEY": "test-local-anon-key"' "$work_dir/dart_define.json" || fail "test_updates_existing_dart_define_in_place: SUPABASE_ANON_KEY not updated"

  rm -rf "$work_dir"
  echo "PASS: test_updates_existing_dart_define_in_place"
}

test_status_parse_failure_exits_nonzero() {
  local work_dir
  work_dir="$(mktemp -d)"
  local bin_dir="$work_dir/bin"
  mkdir -p "$bin_dir"

  cat > "$bin_dir/docker" <<'EOF'
#!/usr/bin/env bash
if [ "$1" = "info" ]; then
  exit 0
fi
exit 0
EOF
  chmod +x "$bin_dir/docker"

  cat > "$bin_dir/npx" <<'EOF'
#!/usr/bin/env bash
if [ "$1" = "supabase" ] && [ "$2" = "status" ]; then
  echo "unparseable status output with no API URL or anon key"
  exit 0
fi
exit 0
EOF
  chmod +x "$bin_dir/npx"

  cat > "$work_dir/dart_define.example.json" <<'EOF'
{
  "SUPABASE_URL": "https://xxxxxxxxxxxx.supabase.co",
  "SUPABASE_ANON_KEY": "your-publishable-key-here"
}
EOF

  local output
  if output=$(PATH="$bin_dir:/usr/bin" SUPABASE_START_REPO_ROOT="$work_dir" bash "$TARGET_SCRIPT" 2>&1); then
    fail "test_status_parse_failure_exits_nonzero: expected non-zero exit"
  fi
  echo "$output" | grep -q "failed to parse" || fail "test_status_parse_failure_exits_nonzero: missing error message. Got: $output"

  if [ -f "$work_dir/dart_define.json" ]; then
    grep -q '"SUPABASE_URL": "https://xxxxxxxxxxxx.supabase.co"' "$work_dir/dart_define.json" || fail "test_status_parse_failure_exits_nonzero: dart_define.json left in a partially-updated state"
    grep -q '"SUPABASE_ANON_KEY": "your-publishable-key-here"' "$work_dir/dart_define.json" || fail "test_status_parse_failure_exits_nonzero: dart_define.json left in a partially-updated state"
  fi

  rm -rf "$work_dir"
  echo "PASS: test_status_parse_failure_exits_nonzero"
}

test_docker_not_installed
test_docker_not_running
test_docker_running_starts_supabase
test_happy_path_updates_dart_define
test_updates_existing_dart_define_in_place
test_status_parse_failure_exits_nonzero

echo "All tests passed."
