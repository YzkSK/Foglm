# テスト基盤構築 Implementation Plan (Issue #53)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Flutter側とSupabase Edge Functions(Deno)側それぞれにテスト実行の土台を整え、CIで両方が動くようにする。あわせて将来の主要ロジック実装時に従うテスト方針ドキュメントを作る。

**Architecture:** Flutter側は`test/unit`と`test/widget`にディレクトリを分け、`mocktail`で依存をモックするサンプル単体テストを1つ追加する。Supabase側は最小のサンプルEdge Function(`hello`)と対応する`deno test`を追加し、CIワークフローに`deno test`ステップを新設する。最後にテスト方針ドキュメントを書く。

**Tech Stack:** Flutter (`flutter_test`, 新規追加`mocktail`), Deno (`deno test`, 標準ライブラリの`assert`), GitHub Actions (`denoland/setup-deno@v1`)

## Global Constraints

- `pubspec.yaml`の`dev_dependencies`に追加してよい新規パッケージは`mocktail`のみ(spec承認済み)。他のパッケージを勝手に追加しない。
- テストカバレッジ計測・CI閾値チェックはスコープ外。追加しない。
- フィルム上限排他制御・投票締切集計・猶予期間判定の実際のロジック実装・テストコードは書かない(方針ドキュメントのみ)。
- 既存の`.github/workflows/ci.yml`の`flutter-ci`ジョブは変更しない。新しいジョブとして追加する。
- 依頼されていないファイルは変更しない。

---

### Task 1: Flutterテストディレクトリ再編とmocktail導入

**Files:**
- Modify: `pubspec.yaml` (dev_dependenciesに`mocktail`追加)
- Create: `test/widget/widget_test.dart` (既存`test/widget_test.dart`の内容を移動)
- Delete: `test/widget_test.dart`
- Create: `test/unit/greeting_service_test.dart`

**Interfaces:**
- Consumes: なし(このタスクが基盤の起点)
- Produces:
  - `test/unit/`ディレクトリ配下に単体テストを置く方針
  - `test/widget/`ディレクトリ配下にウィジェットテストを置く方針
  - テストファイル内で完結する`GreetingRepository`(abstract class, `String greet(String name)`)と`MockGreetingRepository`(mocktailの`Mock`を継承)というサンプルパターン

- [ ] **Step 1: `pubspec.yaml`にmocktailを追加**

`dev_dependencies:`セクションを以下のように変更する:

```yaml
dev_dependencies:
  flutter_test:
    sdk: flutter

  mocktail: ^1.0.4

  # The "flutter_lints" package below contains a set of recommended lints to
  # encourage good coding practices. The lint set provided by the package is
  # activated in the `analysis_options.yaml` file located at the root of your
  # package. See that file for information about deactivating specific lint
  # rules and activating additional ones.
  very_good_analysis: ^10.3.0
```

- [ ] **Step 2: 依存を取得**

Run: `flutter pub get`
Expected: `Got dependencies!` と表示され、`pubspec.lock`に`mocktail`が追加される。

- [ ] **Step 3: 既存ウィジェットテストを`test/widget/`へ移動**

`test/widget_test.dart`の内容をそのまま`test/widget/widget_test.dart`として作成する:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:foglm/app/app.dart';

void main() {
  testWidgets('FoglmApp shows the placeholder home screen', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: FoglmApp()),
    );

    expect(find.text('Foglm'), findsOneWidget);
  });
}
```

そして元の`test/widget_test.dart`を削除する。

- [ ] **Step 4: 移動後のウィジェットテストを実行して成功を確認**

Run: `flutter test test/widget/widget_test.dart`
Expected: `All tests passed!`

- [ ] **Step 5: mocktailを使ったサンプル単体テストを作成する(失敗させる)**

`test/unit/greeting_service_test.dart`を作成する:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

abstract class GreetingRepository {
  String greet(String name);
}

class MockGreetingRepository extends Mock implements GreetingRepository {}

String buildWelcomeMessage(GreetingRepository repository, String name) {
  return repository.greet(name);
}

void main() {
  group('buildWelcomeMessage', () {
    test('delegates to the repository and returns its result', () {
      final repository = MockGreetingRepository();
      when(() => repository.greet('Foglm')).thenReturn('Hello, Foglm!');

      final result = buildWelcomeMessage(repository, 'Foglm');

      expect(result, 'Hello, Foglm!');
      verify(() => repository.greet('Foglm')).called(1);
    });
  });
}
```

- [ ] **Step 6: テストを実行して成功することを確認**

Run: `flutter test test/unit/greeting_service_test.dart`
Expected: `All tests passed!`(mocktailのセットアップに問題があれば失敗するので、ここで検証する)

- [ ] **Step 7: プロジェクト全体のテストを実行**

Run: `flutter test`
Expected: `test/unit/greeting_service_test.dart`と`test/widget/widget_test.dart`の両方が実行され、`All tests passed!`

- [ ] **Step 8: フォーマット・解析を確認**

Run: `dart format --output=none --set-exit-if-changed .`
Expected: 差分なし(exit code 0)

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 9: コミット**

```bash
git add pubspec.yaml pubspec.lock test/unit/greeting_service_test.dart test/widget/widget_test.dart
git rm test/widget_test.dart
git commit -m "test: add mocktail and reorganize test directories into unit/widget"
```

---

### Task 2: Supabase Edge Functionsのサンプル関数とDenoテスト追加

**Files:**
- Create: `supabase/functions/hello/index.ts`
- Create: `supabase/functions/hello/index.test.ts`

**Interfaces:**
- Consumes: なし
- Produces: `buildGreeting(name: string): string`という純粋関数(`index.ts`からexport)。CIの`deno test`ステップが対象にする実体。

- [ ] **Step 1: サンプルEdge Functionを作成**

`supabase/functions/hello/index.ts`:

```typescript
export function buildGreeting(name: string): string {
  const trimmed = name.trim();
  return `Hello, ${trimmed.length > 0 ? trimmed : "world"}!`;
}

Deno.serve(async (req: Request) => {
  const url = new URL(req.url);
  const name = url.searchParams.get("name") ?? "";

  return new Response(
    JSON.stringify({ message: buildGreeting(name) }),
    { headers: { "Content-Type": "application/json" } },
  );
});
```

- [ ] **Step 2: 対応するテストを作成(先に失敗を確認する場合はindex.tsをコメントアウトして試すが、今回は既存関数に対するテストとして作成)**

`supabase/functions/hello/index.test.ts`:

```typescript
import { assertEquals } from "jsr:@std/assert@1";
import { buildGreeting } from "./index.ts";

Deno.test("buildGreeting returns a personalized greeting", () => {
  assertEquals(buildGreeting("Foglm"), "Hello, Foglm!");
});

Deno.test("buildGreeting falls back to 'world' for empty input", () => {
  assertEquals(buildGreeting("   "), "Hello, world!");
});
```

- [ ] **Step 3: テストを実行して成功を確認**

Run: `deno test --allow-none supabase/functions/hello/index.test.ts`
Expected: `ok | 2 passed | 0 failed`

(ローカルにDenoが未インストールの場合は`https://deno.land/`の手順に従いインストールするか、CI実行結果で確認する)

- [ ] **Step 4: フォーマット・lintを確認**

Run: `cd supabase/functions && deno fmt --check hello/ && deno lint hello/`
Expected: 差分・エラーなし

- [ ] **Step 5: コミット**

```bash
git add supabase/functions/hello/index.ts supabase/functions/hello/index.test.ts
git commit -m "test: add sample edge function with deno test coverage"
```

---

### Task 3: CIワークフローにDenoテストジョブを追加

**Files:**
- Modify: `.github/workflows/ci.yml`

**Interfaces:**
- Consumes: Task 2で作成した`supabase/functions/hello/index.test.ts`
- Produces: `deno-ci`という新規ジョブ(既存`flutter-ci`ジョブとは独立して並列実行される)

- [ ] **Step 1: `ci.yml`に`deno-ci`ジョブを追加**

`.github/workflows/ci.yml`を以下の内容に変更する(既存`flutter-ci`ジョブの下に追記):

```yaml
name: CI

on:
  pull_request:
    branches: [main]
  push:
    branches: [main]

jobs:
  flutter-ci:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.44.4'
          channel: 'stable'

      - name: Install dependencies
        run: flutter pub get

      - name: Check formatting
        run: dart format --output=none --set-exit-if-changed .

      - name: Analyze
        run: flutter analyze

      - name: Run tests
        run: flutter test

  deno-ci:
    runs-on: ubuntu-latest
    defaults:
      run:
        working-directory: supabase/functions
    steps:
      - uses: actions/checkout@v4

      - uses: denoland/setup-deno@v2
        with:
          deno-version: v2.x

      - name: Check formatting
        run: deno fmt --check .

      - name: Lint
        run: deno lint .

      - name: Run tests
        run: deno test --allow-none .
```

- [ ] **Step 2: ローカルでYAML構文を確認**

Run: `cd "c:/Users/Yuzuki/Documents/GitHub/Foglm" && cat .github/workflows/ci.yml`
Expected: 上記の内容通りに表示される(YAMLのインデント崩れがないことを目視確認)

- [ ] **Step 3: コミット**

```bash
git add .github/workflows/ci.yml
git commit -m "ci: add deno test job for supabase edge functions"
```

- [ ] **Step 4: プッシュしてGitHub Actions上で両ジョブが成功することを確認**

Run: `git push -u origin feature/test-infrastructure-setup`
Expected: pushが成功し、GitHub Actions上で`flutter-ci`と`deno-ci`の両方が緑になる(PR作成後に確認)

---

### Task 4: テスト方針ドキュメント作成

**Files:**
- Create: `docs/testing-policy.md`

**Interfaces:**
- Consumes: なし
- Produces: 今後のロジック実装Issueが参照するテスト方針ドキュメント

- [ ] **Step 1: ドキュメントを作成**

`docs/testing-policy.md`:

```markdown
# テスト方針

このドキュメントは、Foglmの主要ロジックを実装する際に従うテスト方針をまとめたものです。
実際のテストコードは各ロジックの実装Issueで書きます。ここでは方針のみを定義します。

## フィルム上限の排他制御

- 複数リクエストが同時に同じフィルムへ書き込もうとした場合でも、上限を超えて書き込まれないことを保証する。
- テスト観点:
  - 上限ちょうどの件数までは成功すること。
  - 上限+1件目のリクエストは拒否される、または待機後に失敗すること。
  - 同時実行(並行)リクエストをシミュレートした場合でも上限を超えないこと(DBのトランザクション分離レベル・制約に依存するテストはEdge Functions側のintegration testまたはPostgresの制約テストとして書く)。

## 投票締め切り集計

- 締切時刻をまたぐ境界値でのテストを必須とする。
- テスト観点:
  - 締切1秒前に投じられた票は集計に含まれること。
  - 締切ちょうどの時刻に投じられた票の扱い(含める/含めないをロジック確定時に明記し、その通りにテストする)。
  - 締切1秒後に投じられた票は集計に含まれないこと。
  - 集計処理は現在時刻ではなく、対象の締切時刻を引数として受け取れる設計にし、テストから任意の時刻を注入できるようにする。

## 猶予期間判定

- 猶予期間の判定ロジックは、実行時の現在時刻に直接依存させず、時刻を外部から注入可能な設計にする(例: `bool isWithinGracePeriod(DateTime now, DateTime deadline, Duration gracePeriod)`のような純粋関数にする)。
- テスト観点:
  - 猶予期間内・境界値・猶予期間外の3パターンを最低限カバーする。
  - タイムゾーンをまたぐ場合の挙動(UTC統一かどうかを実装時に確定し、その前提でテストする)。

## 共通方針

- 上記いずれのロジックも、時刻やDBアクセスなど外部要因に依存する部分は抽象化し、単体テストでは`mocktail`(Flutter側)またはDenoの標準的なスタブ手法(Edge Functions側)で差し替えられるようにする。
- 単体テストで検証しきれない排他制御・実DBが絡む挙動は、integration testとして別途検討する(本ドキュメントの対象外。必要になった時点で別Issueとする)。
```

- [ ] **Step 2: コミット**

```bash
git add docs/testing-policy.md
git commit -m "docs: add testing policy for film limit, vote deadline, and grace period logic"
```

---

## 完了確認

- [ ] `flutter test`がローカルで成功する
- [ ] `deno test --allow-none supabase/functions/hello`がローカルまたはCIで成功する
- [ ] GitHub Actions上で`flutter-ci`と`deno-ci`の両ジョブが成功する
- [ ] `docs/testing-policy.md`がコミットされている
