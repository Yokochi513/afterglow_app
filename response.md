## 修正内容

`email` を `users/{uid}` から `users/{uid}/private/profile` サブコレクションに分離し、本人のみ読み書きできるようにしました。

**変更したファイル**

- **`firestore.rules`** — `users/{userId}` 配下に `match /private/{document=**}` を追加し、`request.auth.uid == userId` のみ読み書き許可（管理者含め他人は不可）
- **`lib/models/app_user.dart`** — `email` / `emailNotification` フィールドを削除（`users/{uid}` は投稿者名・アバター表示のため全ログインユーザーに公開される公開プロフィール専用に）
- **`lib/services/auth_service.dart`** — `register()` が `users/{uid}`（公開）と `users/{uid}/private/profile`（メール等）を同一バッチで作成
- **`functions/src/index.ts`** — `onUserCreated` トリガーの監視先を `users/{uid}/private/profile` に変更し、`username` は公開ドキュメントから `get()` で取得。`handleApproval` の却下処理で非公開ドキュメントも削除するよう追加
- **`docs/詳細設計.md`** — 新しいスキーマとルールに合わせて §3.2 / §4.3 / §7.2 を更新（正典ドキュメントなので実装と合わせて修正）
- **テスト** — `test/services/auth_service_test.dart` を新スキーマに追随、`test/rules/users.test.mjs` に非公開プロフィールの読み書き可否テストを追加（本人のみ可、他人・管理者・未ログインは不可）

**検証済み**
- `flutter analyze` — 既存の無関係な警告のみ（今回の変更に起因するものなし）
- `flutter test` — 全件成功（1件の失敗は変更前から存在する無関係な `post_add_dialog_test.dart` の不具合）
- `dart format --set-exit-if-changed .` — 差分なし
- `npm --prefix functions run build` — 成功

**未検証**
- `test/rules`（Firestore エミュレータでのルール評価）は、この環境に Java が無いため実行できませんでした。CI（`.github/workflows/firestore-rules.yml`）または Java が入った環境で `npm --prefix test/rules ci && npm --prefix test/rules test` を実行して確認してください。

**注意点**
- 既存ユーザーは `users/{uid}` に `email` フィールドが残ったままです。本番デプロイ後、既存ドキュメントの `email` を `private/profile` へ移してから元フィールドを削除するマイグレーションが別途必要です（今回のコード変更だけでは既存データの `email` は消えません）。
- ルール・Functions の反映は `firebase deploy --only firestore:rules` と `firebase deploy --only functions` が必要です（コード変更だけではデプロイされません）。