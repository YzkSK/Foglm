# デバッグ用画面(DebugMenuScreen)

開発中に、実装済みの各画面(カメラ・サインアップ・パスワードリセット等)へ本番導線を経由せず直接遷移して動作確認するための画面。

`APP_PROFILE=dev`を指定してビルド・実行した場合のみ有効になり、本番ビルドのエンドユーザーには到達不可能(`lib/core/router/app_router.dart`で`devProfile`のときのみ`/debug`ルートを登録している)。

## 実行方法

```bash
flutter run --dart-define=APP_PROFILE=dev --dart-define-from-file=dart_define.json
```

`APP_PROFILE`も`dart_define.json`にまとめて管理したい場合は、同ファイルに`"APP_PROFILE": "dev"`を追加してもよい(`--dart-define`は`--dart-define-from-file`より後に指定すると上書きされるため、まとめる場合はコマンドラインの`--dart-define=APP_PROFILE=dev`は不要になる)。

## アクセス方法

`APP_PROFILE=dev`でビルド・実行すると、アプリ起動直後に自動的にデバッグメニュー(`/debug`)が表示される。各ボタンから実装済みの画面へ遷移できる。
