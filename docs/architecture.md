# アーキテクチャ規約

Foglmのクライアント(`lib/`)はクリーンアーキテクチャを採用し、`lib/features/<feature>/` 配下を4層に分ける。
このドキュメントは各層の責務・依存の向き・命名規則を定める。**このドキュメント自体はコードを変更しない。** 既存ディレクトリ構成の是正は #245、UseCase層の導入は #216、lintによる強制は #217 で行う。

## 背景・決定事項

突貫で機能を積み上げた結果、featureごとに層構成がバラついていた(#214)。codexレビューでは「RiverpodのAsyncNotifierが既に薄いUseCase役を担っているので、全面的なUseCase強制は定型コードが増えて重い。`presentation → data` の import禁止だけを強制し、UseCase化は複数Repositoryをまたぐ処理に限定するのが現実的」という反対意見があった。

これを踏まえた上で、**一貫性とテスト容易性を優先し、全featureでUseCase層を強制する方針を採る**ことを決定した(決定者: @YzkSK)。単純なCRUDでも定型コードが増えるコストは受け入れる。

移行は機能追加を止めないよう、feature単位で段階的に行う(1 feature = 1 PR)。移行順の案: `album`(画面未実装で影響が小さい) → `camera` → `candidates` → `groups` → `auth`。

## 1. 4層の責務

```
lib/features/<feature>/
  presentation/   … Widget / Screen。application のみに依存する
  application/    … Controller(AsyncNotifier) + UseCase。domain に依存する
    usecase/
  domain/         … エンティティ、値オブジェクト、失敗型、Repositoryの抽象interface
  data/           … Repositoryの実装(Supabase等の外部I/O)。domain のinterfaceを実装する
```

| 層 | 責務 | 知ってよいもの |
|---|---|---|
| **presentation** | 画面・Widget。ユーザー操作を受け取り、Controllerの状態を描画する | application層(Controllerの状態・メソッド) |
| **application** | Controller(AsyncNotifier)がUI向けの状態を保持し、UseCaseを呼び出して結果を反映する。UseCaseはUI操作単位のapplication service(単純なCRUDではRepositoryへの薄い委譲でよく、複数Repositoryをまたぐ処理・業務ルールの適用はUseCaseに寄せる) | domain層(エンティティ、Repository抽象interface)。providerの配線(wiring)に限り、実装を束ねるためdata層のRepository providerを参照してよい |
| **domain** | エンティティ、値オブジェクト、失敗型(`*Failure`)、Repositoryの抽象interface。フレームワーク・I/Oに依存しない純粋なDart | 何にも依存しない(最も内側) |
| **data** | Repositoryの実装。Supabase(Postgres/Auth/Storage/Edge Function)など外部I/Oを担う | domain層(実装するinterface)、および`core/`配下の共通インフラ・外部SDK(`supabase_flutter`等) |

Widgetのうち、特定のScreenに属さず複数箇所から再利用される部品は `presentation/` ではなく feature直下の `widgets/` に置いてよい(例: `auth/widgets/logout_button.dart`)。`widgets/` は presentation層の一部として扱い、依存ルールも同様に適用する。

## 2. 依存の向き

```
presentation → application → domain ← data
```

domainが最も内側にあり、何にも依存しない。data はdomainのinterfaceを実装することでdomainに依存する(依存性逆転)。

### 禁止事項

- presentation から data への直接import禁止(必ずapplicationを経由する)
- feature をまたぐ data のimport禁止(feature間はapplication層以上を経由する)
- domain から他のどの層への依存も禁止(domain以外の層を一切importしない)
- Controller が Repository を直接importすることを禁止し、UseCase経由を必須とする(#216完了後に適用。それまでの既存コードはこの禁止の適用対象外)
- 例外: UseCase・ControllerのproviderがRepository providerを注入するための配線(`ref.watch(xxxRepositoryProvider)`)に限り、application層からdata層のRepository providerをimportしてよい。ビジネスロジックでの直接呼び出しは対象外(上記の禁止を参照)

これらは #217 で `custom_lint` により機械的に強制する。それまでは本ドキュメントを規約として運用する。

## 3. 命名規則

| 種別 | 命名 | 配置層 |
|---|---|---|
| 画面 | `*_screen.dart` | presentation |
| Controller(AsyncNotifier) | `*_controller.dart` | application |
| UseCase | `*_usecase.dart` | application/usecase |
| Repository実装 | `*_repository.dart` | data |
| Repository抽象interface | `*_repository.dart`(dataと同名。ファイルはdomainに置く) | domain |
| エンティティ・値オブジェクト | 命名は自由(例: `my_group.dart`, `album_photo.dart`) | domain |
| 失敗型 | `*_failure.dart` | domain |

## 4. Riverpodのproviderをどの層に置くか

- **UseCase・Repositoryのproviderは、そのクラスが属する層のファイルに置く**(Repository実装のproviderはdata層のファイル内、UseCaseのproviderはapplication層のファイル内)。
- **UI向けに整形したデータを流すproviderはapplication層に置く**。data層に置かない(例: `today_candidates_provider.dart` は `data/` ではなく `application/` に置く。現状の逸脱は#245で是正)。
- **Controller自身がAsyncNotifierProviderとして公開されるproviderもapplication層に置く**。

## 5. 関連ドキュメントとの関係

- `docs/api-flows.md`(#220でマージ予定。マージまでは[`docs/spec.md`の6章](./spec.md#6-api仕様supabase-rpc--edge-functions)を参照): クライアントとバックエンド間の**通信経路**(Auth API / Edge Function / RPC / 直接テーブル / Realtime)をどう選ぶかを定める。本ドキュメントはクライアント内部の**層構成**を定めるもので、扱う領域が異なる。data層のRepository実装がapi-flows.mdの規約に従って通信経路を選ぶ、という関係にある。
- [`docs/testing-policy.md`](./testing-policy.md): 主要ロジックのテスト観点を定める。UseCase・domainのロジックはこのドキュメントの方針に従ってテストする。
- [`docs/spec.md`](./spec.md): 「何を」提供するかの仕様。本ドキュメントは「どう」実装するかを定める。

## 6. 子issue

- [ ] #245 ディレクトリ構成をレイヤ規約に揃える(機械的な移動のみ)
- [ ] #216 UseCase層の導入と、Controllerからの呼び出しへの置換
- [ ] #217 custom_lintによるレイヤ依存方向の強制
