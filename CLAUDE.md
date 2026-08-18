# CLAUDE.md

Afterglow（`afterglow_app`）で作業する際の指針。Claude はこのファイルの指示を優先して守ること。

## プロジェクト概要

地図上に写真付き投稿をピン留めできる Flutter + Firebase アプリ。OpenStreetMap（`flutter_map`）上で場所を選び、写真とコメントを投稿する。フェーズ 1 は単一メールドメインに閉じたクローズド運用で、新規登録は管理者のメール承認を経て有効化される。

- **クライアント**: Flutter（`lib/`）。Web は GitHub Pages に公開（https://yokochi513.github.io/afterglow_app/ ）。
- **バックエンド**: Firebase（Auth / Cloud Firestore / Storage）+ Cloud Functions（`functions/`, TypeScript）。
- **GitHub**: `Yokochi513/afterglow_app`（default: `main`）。`azure` リモートも存在するが、CI・PR は `origin`（GitHub）を使う。

## ディレクトリ構成と責務

```
lib/
  main.dart              アプリ起点。Firebase 初期化 → AuthGate
  firebase_options.dart  FlutterFire 生成物（追跡済み・手編集しない）
  models/                イミュータブルなデータクラス（Post, AppUser）
  pages/                 画面。auth/ に認証系（AuthGate, login, register, pending_approval）
  services/              Firestore/Storage/Auth へのアクセス層
  widgets/               再利用 UI（post_widget, post_add_dialog 等）
functions/src/index.ts   ユーザー登録の承認フロー（Firestore トリガー + HTTPS）
docs/                    正典ドキュメント（読み取り専用・下記参照）
test/                    models/ services/ widgets/ 単位のテスト
```

レイヤの越境をしない: UI は `pages`/`widgets`、データ入出力は `services`、データ構造は `models`。ウィジェットから Firestore/Storage を直接触らず、必ず `services` を経由する。

## コード規約

- **コメント・ドキュメント・コミット・PR は日本語**（リポジトリの慣習）。ユーザーが言語を指定した場合はそれに従う。
- **サービスは依存注入（DI）**: `PostService({FirebaseFirestore? firestore, FirebaseStorage? storage})` のように Firebase インスタンスをコンストラクタで受け、既定値に `.instance` を使う。テストがモック（`fake_cloud_firestore` / `firebase_storage_mocks` / `firebase_auth_mocks`）を注入できるよう、この形を維持する。
- **モデルはイミュータブル**: `const` コンストラクタ + `factory fromSnapshot(id, Map)`。`AppUser` は `toMap()` も持つ。欠損フィールドは必ず既定値でフォールバックする（`document['x'] ?? ...`）。
- **コレクション名は `static const` 定数**でサービスに定義（例 `postsCollection = 'posts'`）。文字列リテラルを散らさない。
- lint は `flutter_lints`。`flutter analyze` の警告はゼロに保つ。

## Firebase バックエンド構造

- Firestore リージョン: `asia-northeast2`（大阪）。Functions もこれに揃える（`REGION` 定数）。
- コレクション:
  - `posts/{postId}` — 投稿（userId, caption, imageUrls, latitude, longitude, createdAt）
  - `users/{uid}` — ユーザー（username, email, bio, profileImageUrl, role, approved, emailNotification, createdAt）。`role == 'admin'` が管理者。`approved` が承認状態。
  - `registrationApprovals/{uid}` — 承認トークン（一時）
  - `mail/{uid}` — Trigger Email 拡張が読む送信キュー
- Storage パス: 投稿画像 `posts/{userId}/{postId}_{index}.jpg`、プロフィール画像 `profiles/{uid}/avatar.jpg`。
- 承認フロー: `users/{uid}` 作成 → Functions `onUserCreated` が承認メール送信 → 管理者がリンククリック → `handleApproval` が `approved: true`（承認）または各ドキュメント削除（却下）。

## ブランチ戦略

- **`dev` を統合ブランチとし、常に `main` を先行させる**。日常の開発成果は必ず `dev` に集約する。
- **フィーチャーブランチは `dev` から切り、`dev` に PR を出す**。命名は kebab-case で種別接頭辞を付ける（`feat-<slug>`, `fix-<slug>`, Issue 由来なら `feat-<issue番号>-<slug>`）。
- **`main` はリリース線**。リリースのタイミングで `dev` → `main` の PR を出してマージする。`main` へ直接コミット・直接フィーチャーマージはしない。
- **`main` への push は本番デプロイ**: `.github/workflows/deploy.yml` が `main` push で Web をビルドし GitHub Pages へ公開する。したがって `dev` → `main` のマージ = リリース = 公開。壊れた状態を `main` に入れないこと。
- リリース後は `dev` が `main` より遅れないよう、必要なら `main` を `dev` に取り込んで先行状態を保つ。

開発は原則 GitHub Issue を起点にする。実装は `/implement-afterglow-issue` を使い、`dev` からフィーチャーブランチを切って base = `dev` の PR を出す。

## 検証（validation）

Dart/Flutter（`lib/` 等を変更したら実行）:

```bash
flutter pub get
flutter analyze                                   # 警告ゼロを維持
dart format .
dart format --output=none --set-exit-if-changed .
flutter test                                      # モックによりオフラインで実行可
```

Cloud Functions（`functions/` を変更したときのみ）:

```bash
npm --prefix functions ci
npm --prefix functions run build                  # tsc。lint/test スクリプトは未定義
```

Firestore セキュリティルール（`firestore.rules` を変更したときのみ）:

```bash
npm --prefix test/rules ci                        # 初回・依存更新時
npm --prefix test/rules test                      # エミュレータ上でルールを評価
```

Java と firebase CLI が要る。Dart 側のテストは `fake_cloud_firestore` を使っており**ルールを一切評価しない**ため、クライアントの書き込みがルールで拒否される類の不具合はこのテストでしか検出できない（詳細は `test/rules/README.md`）。ルールは `.github/workflows/firestore-rules.yml` が扱う: ルール関連ファイルを含む PR ではこのテストが CI で走り、`main` への push で本番へ自動デプロイされる（リポジトリシークレット `FIREBASE_SERVICE_ACCOUNT` が必要）。手動で反映するなら `firebase deploy --only firestore:rules,storage`。`--only storage:rules` は**エラーになる**（`storage:<デプロイターゲット名>` と解釈されるため）。

Flutter が出力前に固まる場合は Flutter/Dart プロセスと SDK キャッシュのロックを確認する（キャッシュ書き込み権限が必要なことがある）。

## 正典ドキュメント（読み取り専用）

`docs/` は仕様。実装で勝手に書き換えない。仕様変更が要るなら実装せず Issue 等で相談する。

- `docs/要件定義.md` — 要件定義
- `docs/詳細設計.md` — 詳細設計
- `docs/prompts/phase1_roadmap.md` — フェーズ 1 の方針（背景資料。仕様そのものではない）

## コミットしてはいけないもの

秘密情報・生成物は入れない: サービスアカウント鍵、`.env`、APNs キー、`*.keystore`、新規の `google-services.json` / `GoogleService-Info.plist`、ビルド生成物（`build/`, `functions/lib/`）、無関係なユーザー変更。なお `lib/firebase_options.dart` と `.firebaserc` は既に追跡済みで、Issue が要求しない限りそのままにする。
