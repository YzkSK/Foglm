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

## Edge Functionのユニットテスト / integration test

Supabase Edge Functions(`supabase/functions/`)のテストは、依存の有無で2種類に分ける。

- **ユニットテスト**(`*.test.ts`): `SupabaseClient` をモック(スタブ)で差し替え、実DBに依存せず実行する。既存の `supabase/functions/_shared/*.test.ts` を参照。ローカル・CIともに常時実行する。
- **integration test**(`*.integration.test.ts`): ローカルSupabase(実DB)に対して実際に読み書きし、検証する。ファイル名は必ず `*.integration.test.ts` とし、対象コードと同階層に置く(ユニットテストと同じ配置規約)。
  - `Deno.env.get("SUPABASE_URL")` / `Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")` を読み、`createClient` で service_role権限のクライアントを生成する。未設定の場合は例外を投げて即失敗させる(スキップしない)。
  - pgTAPの `begin; ... rollback;` に相当する自動ロールバックが無いため、**テスト自身が作成した行をテスト末尾(`finally` 等)で必ず削除する**。テストデータのIDは `crypto.randomUUID()` 等で他テストと衝突しない値にする。
  - CI(`deno-ci` ジョブ)は `npx supabase start` でローカルSupabaseを起動した上で、ユニットテストとintegration testを別ステップで実行する(`.github/workflows/ci.yml` 参照)。
  - ローカルで実行する場合は、事前に `dart run tool/supabase_start.dart` 等でローカルSupabaseを起動し、`SUPABASE_URL` / `SUPABASE_SERVICE_ROLE_KEY` を環境変数に設定してから `deno test --allow-net --allow-env` を実行する。

## Golden Test(UIの見た目のテスト)

- UIコンポーネント・画面の見た目を検証するGolden Testには`alchemist`パッケージを使う(golden_toolkitはdiscontinuedのため不採用)。
- `test/flutter_test_config.dart`で全体設定を行っており、プラットフォーム固有(`platform`)のgoldenは無効化し、フォント差異の影響を受けない`ci`バリアントのみを使用する。これによりCI(Ubuntu)とローカル(Windows/macOS等)で同じgolden画像を共有できる。
- 配置規則: テストファイルと同階層の`goldens/ci/<fileName>.png`に生成される(`goldens/ci/`配下は自動生成物として扱う)。
- 画面・コンポーネントのGolden Testは`test/golden/`配下に置き、対象ウィジェット単位でファイルを分ける。
- 実行・更新コマンド:
  - 通常実行(差分検知): `flutter test`
  - golden画像の生成・更新: `flutter test --update-goldens`
  - Golden Testのみ実行: `flutter test --tags golden`
- CIでは`flutter test`実行時にgoldenの差分があれば通常のテスト失敗として検知される。失敗時は比較用の差分画像(`failures/`配下)をArtifactとしてアップロードする。

### 対象レイヤーと必須ルール

Golden Testは以下の2レイヤーに分け、**画面(Screen)を実装するIssueでは両方を揃えることを必須**とする(Widget単位のテストのみで画面全体が未検証のまま、という漏れを防ぐため)。

| レイヤー | 対象 | 配置例 | 必須タイミング |
|---|---|---|---|
| Widget単位 | ボタン・カード・リスト項目など、画面内の個別コンポーネント | `test/golden/<feature>/<widget_name>_golden_test.dart` | 再利用可能なWidgetを新規作成した時 |
| Screen単位 | `docs/spec.md`の画面一覧(S01〜S13など)に対応する画面全体 | `test/golden/<feature>/<screen_name>_screen_golden_test.dart` | 画面(Screen)を実装・`GoRoute`に追加した時 |

- 新しい画面を実装するPRでは、その画面に対応する`*_screen_golden_test.dart`を**必ず追加**する。Widget単位のgoldenだけを追加して画面単位を省略しない。
- 逆に、画面単位のgoldenだけでは個々のコンポーネントの状態網羅が難しいため、状態パターンが複数ある部品(ボタンの有効/無効など)はWidget単位でも分けて検証する。

### 状態パターンの網羅

1画面・1コンポーネントにつき、該当する状態は`GoldenTestGroup` / `GoldenTestScenario`(または`goldenTest`を複数呼ぶ)でまとめて1つのgolden画像に網羅する。最低限、以下の観点で該当するものをチェックする。

- **ローディング状態**: データ取得中(`AsyncLoading`)の表示
- **エラー状態**: データ取得失敗・権限エラーなど(`AsyncError`)の表示
- **空状態(empty)**: 一覧系画面でデータが0件の場合の表示
- **通常状態(success)**: データがある場合の表示(件数が少ない/多いなど、レイアウト崩れが起きうる境界も可能な範囲で)
- **入力・操作系のバリエーション**: フォームのバリデーションエラー表示、ボタンの有効/無効など
- 上記のうち画面の性質上存在しない状態(例: フォームがない画面のバリデーションエラー)は対象外でよい。

### サイズ・制約(constraints)

- `constraints`は対象画面が実際に使われる代表的なスマートフォンサイズを基準にする(既存の`CameraScreen`・`FoglmApp`のgoldenに合わせ、特別な理由がなければ`maxWidth: 400, maxHeight: 800`を既定値とする)。
- スクロールが発生する画面(一覧・アルバムなど)で内容が`maxHeight`に収まらない場合は、`constraints`を広げるか、代表的な件数のみを切り出すなど、画面の実装内容に応じて判断する。

### 命名規則

- ファイル名: `<screen_or_widget_name>_golden_test.dart`(例: `camera_screen_golden_test.dart`, `shutter_button_golden_test.dart`)
- `fileName`引数はスネークケースでファイル名と対応させる(例: `fileName: 'login_screen'`)。
- 状態ごとに複数の`GoldenTestScenario`を使う場合、`name`は「状態が分かる日本語 or 英語」で簡潔に(例: `'ローディング中'`, `'空状態'`)。

### 画面実装時のチェックリスト

`docs/spec.md`の画面(S01〜S13等)を実装するPRでは、レビュー前に以下を確認する。

- [ ] 対象画面の`*_screen_golden_test.dart`を`test/golden/<feature>/`配下に追加した
- [ ] 画面が取りうる主要な状態(ローディング/エラー/空/通常など、該当するもの)を`GoldenTestGroup`でまとめて網羅した
- [ ] 画面内の再利用可能なWidgetのうち、状態パターンを持つものはWidget単位のgoldenでも検証した
- [ ] `flutter test --update-goldens`でgolden画像を生成し、意図した見た目になっていることを目視確認した
- [ ] `flutter test`でgoldenの差分検知が通ることを確認した
