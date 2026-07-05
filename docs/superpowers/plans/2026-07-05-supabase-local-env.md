# Supabaseローカル環境 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `scripts/supabase-start.sh` を実行するだけでローカルSupabase環境(DB起動・マイグレーション適用・Flutter側のdart_define.json自動設定)まで立ち上がるようにする。

**Architecture:** Bashスクリプト2本(`scripts/supabase-start.sh` / `scripts/supabase-stop.sh`)を新規作成する。`supabase-start.sh`はDockerの起動状態を確認した上で`npx supabase start` → `npx supabase db reset` を実行し、`npx supabase status`の出力からローカルのAPI URL/anon keyを取得して`dart_define.json`に反映する。テストは`docker`/`npx`コマンドをPATH上でスタブ差し替えすることで、実際のDocker/Supabase環境なしにロジックを検証する。

**Tech Stack:** Bash, Supabase CLI(`npx supabase`), Docker

## Global Constraints

- 依頼されていないファイルは変更しない(このプランの対象ファイル以外に触れない)。
- 新しい依存パッケージ・ツールを追加しない(既存の`npx`経由のSupabase CLI呼び出しのみを使う。`jq`等は導入しない)。
- `dart_define.json`は`.gitignore`済みのローカル専用ファイルであり、書き換え対象は`SUPABASE_URL`/`SUPABASE_ANON_KEY`の2キーのみ。他のキーが将来追加されても保持する。
- 本番/ステージング環境のシークレット自動化は対象外(`docs/setup/secrets.md`の運用を変更しない)。

---

### Task 1: `scripts/supabase-stop.sh`

**Files:**
- Create: `scripts/supabase-stop.sh`
- Test: `scripts/tests/test_supabase_stop.sh`

**Interfaces:**
- Consumes: なし(このタスクが起点)
- Produces: `scripts/supabase-stop.sh` — 引数なしで実行すると`npx supabase stop`を呼ぶだけのラッパー。以降のタスクはこのファイルに依存しない。

- [ ] **Step 1: テストディレクトリを作成し、失敗するテストを書く**

`scripts/tests/test_supabase_stop.sh` を作成する。

```bash
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

  PATH="$bin_dir" bash "$TARGET_SCRIPT" > /dev/null

  grep -q "supabase stop" "$call_log" || fail "test_calls_supabase_stop: npx was not called with 'supabase stop'"

  rm -rf "$work_dir"
  echo "PASS: test_calls_supabase_stop"
}

test_calls_supabase_stop

echo "All tests passed."
```

- [ ] **Step 2: テストを実行して失敗することを確認する**

Run: `bash scripts/tests/test_supabase_stop.sh`
Expected: `scripts/supabase-stop.sh: No such file or directory` のようなエラーで失敗する。

- [ ] **Step 3: `scripts/supabase-stop.sh` を実装する**

```bash
#!/usr/bin/env bash
set -euo pipefail

echo "Stopping local Supabase environment..."
npx supabase stop
```

実行権限を付与する。

Run: `chmod +x scripts/supabase-stop.sh`

- [ ] **Step 4: テストを再実行してパスすることを確認する**

Run: `bash scripts/tests/test_supabase_stop.sh`
Expected: `PASS: test_calls_supabase_stop` および `All tests passed.` が出力される。

- [ ] **Step 5: コミット**

```bash
git add scripts/supabase-stop.sh scripts/tests/test_supabase_stop.sh
git commit -m "feat: Supabaseローカル環境の停止スクリプトを追加"
```

---

### Task 2: `scripts/supabase-start.sh` — Docker確認 + 起動 + マイグレーション適用

**Files:**
- Create: `scripts/supabase-start.sh`
- Test: `scripts/tests/test_supabase_start.sh`

**Interfaces:**
- Consumes: なし
- Produces: `scripts/supabase-start.sh` — 環境変数`SUPABASE_START_REPO_ROOT`が設定されていればそれをリポジトリルートとして使う(未設定時はスクリプトの1つ上の階層を使う)。このタスクの時点では「Dockerが無い/起動していない場合にエラー終了する」「Dockerが起動していれば`npx supabase start`と`npx supabase db reset`を呼ぶ」ところまでを実装する。Task 3でdart_define.json更新ロジックをこのファイルに追記する。

- [ ] **Step 1: 失敗するテストを書く**

`scripts/tests/test_supabase_start.sh` を作成する。

```bash
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_SCRIPT="$SCRIPT_DIR/../supabase-start.sh"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

test_docker_not_installed() {
  local work_dir
  work_dir="$(mktemp -d)"
  local bin_dir="$work_dir/bin"
  mkdir -p "$bin_dir"

  local output
  if output=$(PATH="$bin_dir" SUPABASE_START_REPO_ROOT="$work_dir" bash "$TARGET_SCRIPT" 2>&1); then
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
  if output=$(PATH="$bin_dir" SUPABASE_START_REPO_ROOT="$work_dir" bash "$TARGET_SCRIPT" 2>&1); then
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

  PATH="$bin_dir" SUPABASE_START_REPO_ROOT="$work_dir" bash "$TARGET_SCRIPT" > /dev/null

  grep -q "supabase start" "$call_log" || fail "test_docker_running_starts_supabase: 'supabase start' was not called"
  grep -q "supabase db reset" "$call_log" || fail "test_docker_running_starts_supabase: 'supabase db reset' was not called"

  rm -rf "$work_dir"
  echo "PASS: test_docker_running_starts_supabase"
}

test_docker_not_installed
test_docker_not_running
test_docker_running_starts_supabase

echo "All tests passed."
```

- [ ] **Step 2: テストを実行して失敗することを確認する**

Run: `bash scripts/tests/test_supabase_start.sh`
Expected: `scripts/supabase-start.sh: No such file or directory` のようなエラーで失敗する。

- [ ] **Step 3: `scripts/supabase-start.sh` を実装する(Docker確認 + 起動 + マイグレーション適用まで)**

```bash
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
```

実行権限を付与する。

Run: `chmod +x scripts/supabase-start.sh`

- [ ] **Step 4: テストを再実行してパスすることを確認する**

Run: `bash scripts/tests/test_supabase_start.sh`
Expected: `PASS: test_docker_not_installed`, `PASS: test_docker_not_running`, `PASS: test_docker_running_starts_supabase`, `All tests passed.` が出力される。

- [ ] **Step 5: コミット**

```bash
git add scripts/supabase-start.sh scripts/tests/test_supabase_start.sh
git commit -m "feat: Supabaseローカル環境の起動スクリプトを追加(Docker確認+起動+migration適用)"
```

---

### Task 3: `dart_define.json` 自動反映ロジックの追加

**Files:**
- Modify: `scripts/supabase-start.sh`
- Modify: `scripts/tests/test_supabase_start.sh`

**Interfaces:**
- Consumes: Task 2で作成した`scripts/supabase-start.sh`(`REPO_ROOT`変数、Docker確認〜`npx supabase db reset`までの処理)
- Produces: `scripts/supabase-start.sh`が完了時に`$REPO_ROOT/dart_define.json`を作成/更新する。存在しなければ`dart_define.example.json`からコピーし、`SUPABASE_URL`/`SUPABASE_ANON_KEY`の値を`npx supabase status`の出力から取得した値で上書きする(他のキーは保持)。

- [ ] **Step 1: 失敗するテストを追記する**

`scripts/tests/test_supabase_start.sh` の `test_docker_running_starts_supabase` 定義の後、`test_docker_not_installed` / `test_docker_not_running` / `test_docker_running_starts_supabase` の呼び出し行の直前に、以下のテスト関数と呼び出しを追加する。

```bash
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
  "SUPABASE_ANON_KEY": "your-publishable-key-here"
}
EOF

  PATH="$bin_dir" SUPABASE_START_REPO_ROOT="$work_dir" bash "$TARGET_SCRIPT" > /dev/null

  [ -f "$work_dir/dart_define.json" ] || fail "test_happy_path_updates_dart_define: dart_define.json not created"
  grep -q '"SUPABASE_URL": "http://127.0.0.1:54321"' "$work_dir/dart_define.json" || fail "test_happy_path_updates_dart_define: SUPABASE_URL not updated"
  grep -q '"SUPABASE_ANON_KEY": "test-local-anon-key"' "$work_dir/dart_define.json" || fail "test_happy_path_updates_dart_define: SUPABASE_ANON_KEY not updated"

  rm -rf "$work_dir"
  echo "PASS: test_happy_path_updates_dart_define"
}
```

呼び出し部分は以下のようになる(既存の3行の下に1行追加)。

```bash
test_docker_not_installed
test_docker_not_running
test_docker_running_starts_supabase
test_happy_path_updates_dart_define

echo "All tests passed."
```

- [ ] **Step 2: テストを実行して失敗することを確認する**

Run: `bash scripts/tests/test_supabase_start.sh`
Expected: `FAIL: test_happy_path_updates_dart_define: dart_define.json not created`(他の3テストはPASSのまま)

- [ ] **Step 3: `scripts/supabase-start.sh` に dart_define.json 更新ロジックを追記する**

`npx supabase db reset` の行の後に以下を追記する。

```bash
DART_DEFINE_FILE="$REPO_ROOT/dart_define.json"
DART_DEFINE_EXAMPLE="$REPO_ROOT/dart_define.example.json"

if [ ! -f "$DART_DEFINE_FILE" ]; then
  echo "Creating dart_define.json from dart_define.example.json..."
  cp "$DART_DEFINE_EXAMPLE" "$DART_DEFINE_FILE"
fi

STATUS_OUTPUT="$(npx supabase status)"

API_URL="$(echo "$STATUS_OUTPUT" | grep -i -E '^[[:space:]]*API URL' | head -n1 | sed -E 's/^[^:]*:[[:space:]]*//')"
ANON_KEY="$(echo "$STATUS_OUTPUT" | grep -i -E '^[[:space:]]*anon key' | head -n1 | sed -E 's/^[^:]*:[[:space:]]*//')"

if [ -z "$API_URL" ] || [ -z "$ANON_KEY" ]; then
  echo "Error: failed to parse 'supabase status' output. dart_define.json was not updated." >&2
  exit 1
fi

sed -i.bak -E "s#(\"SUPABASE_URL\"[[:space:]]*:[[:space:]]*)\"[^\"]*\"#\1\"$API_URL\"#" "$DART_DEFINE_FILE"
sed -i.bak -E "s#(\"SUPABASE_ANON_KEY\"[[:space:]]*:[[:space:]]*)\"[^\"]*\"#\1\"$ANON_KEY\"#" "$DART_DEFINE_FILE"
rm -f "$DART_DEFINE_FILE.bak"

echo ""
echo "Local Supabase environment is ready."
echo "  API URL: $API_URL"
echo "dart_define.json has been updated with the local anon key."
```

- [ ] **Step 4: テストを再実行してすべてパスすることを確認する**

Run: `bash scripts/tests/test_supabase_start.sh`
Expected: `PASS: test_docker_not_installed`, `PASS: test_docker_not_running`, `PASS: test_docker_running_starts_supabase`, `PASS: test_happy_path_updates_dart_define`, `All tests passed.` が出力される。

- [ ] **Step 5: コミット**

```bash
git add scripts/supabase-start.sh scripts/tests/test_supabase_start.sh
git commit -m "feat: supabase-start.shでdart_define.jsonにローカルのURL/anon keyを自動反映"
```

---

### Task 4: `docs/setup/supabase.md` の更新

**Files:**
- Modify: `docs/setup/supabase.md`(セクション3)

**Interfaces:**
- Consumes: Task 1〜3で作成した`scripts/supabase-start.sh` / `scripts/supabase-stop.sh`
- Produces: なし(ドキュメントのみ)

- [ ] **Step 1: セクション3を書き換える**

現在の記述:

```markdown
## 3. ローカル開発環境の起動(任意・現時点ではスキップ中)

ローカル開発にはDockerが必要。現状は導入コストに対してメリットが薄いため見送っており、クラウド上の開発用プロジェクトに直接マイグレーションを反映して動作確認する運用としている。RLSやトリガーなど壊れやすい変更を試す機会が増えてきたタイミングで、改めて導入を検討する。

```bash
npx supabase start
```

停止する場合は `npx supabase stop`。
```

これを以下に置き換える。

```markdown
## 3. ローカル開発環境の起動

以前はDocker導入コストに対してメリットが薄いため見送っていたが、RLSやトリガーなど壊れやすい変更を
試す機会が増えてきたため、ローカル環境を導入した。ローカル開発にはDockerが必要。

以下のスクリプトを実行すると、ローカルDBの起動・マイグレーション適用・Flutter側の接続設定
(`dart_define.json`)までが一括で行われる。

```bash
./scripts/supabase-start.sh
```

初回実行時はDockerイメージの取得が入るため時間がかかる。実行後、`dart_define.json`が
無ければ`dart_define.example.json`からコピーされた上で、`SUPABASE_URL`/`SUPABASE_ANON_KEY`が
ローカル環境の値に書き換えられる(ローカル固定の開発用キーであり、本番のSecret key等とは無関係)。

停止する場合は以下を実行する。

```bash
./scripts/supabase-stop.sh
```
```

- [ ] **Step 2: 変更内容を確認する**

Run: `git diff docs/setup/supabase.md`
Expected: セクション3が上記の内容に置き換わっている。

- [ ] **Step 3: コミット**

```bash
git add docs/setup/supabase.md
git commit -m "docs: Supabaseローカル環境の起動手順をスクリプト利用に更新"
```
