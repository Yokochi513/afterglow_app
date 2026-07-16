# Afterglow

地図上に写真付き投稿をピン留めできる Flutter アプリです。OpenStreetMap の地図上で場所を選び、写真とコメントを投稿できます。

## 公開ページ

GitHub Pages で Web 版を公開しています。

- https://yokochi513.github.io/afterglow_app/

## 主な機能

- OpenStreetMap を使った地図表示
- 地図タップ位置への投稿作成
- 画像付き投稿のアップロード
- Firestore による投稿のリアルタイム購読
- Firebase Authentication を使ったログイン導線
- Firebase Storage による投稿画像の保存

## 技術構成

- Flutter
- Firebase
  - Authentication
  - Cloud Firestore
  - Firebase Storage
- OpenStreetMap
- flutter_map

## ローカル実行

```bash
flutter pub get
flutter run -d chrome
```

モバイルエミュレータで実行する場合:

```bash
flutter run
```

## テスト

```bash
flutter test
```

テストでは `fake_cloud_firestore` と `firebase_storage_mocks` を使用しているため、ネットワーク接続なしで実行できます。

## デプロイ

`main` ブランチに push すると、GitHub Actions で Web ビルドを作成し、GitHub Pages へ自動デプロイします。

手動実行も GitHub Actions の `Deploy demo to GitHub Pages` ワークフローから可能です。

ビルド時は GitHub Pages のサブパスに合わせて、次の `base-href` を指定しています。

```bash
flutter build web --release --base-href "/afterglow_app/"
```

## ディレクトリ構成

レイヤの責務を分離しています。UI は `pages` / `widgets`、データ入出力は `services`、データ構造は `models` が担当し、ウィジェットから Firestore / Storage を直接触らず必ず `services` を経由します。

```text
lib/                    Flutter アプリ本体
  main.dart             アプリ起点。Firebase 初期化 → AuthGate
  firebase_options.dart FlutterFire 生成物（手編集しない）
  models/               イミュータブルなデータクラス
  pages/                画面（auth/ に認証系）
  services/             Firestore / Storage / Auth へのアクセス層
  widgets/              再利用 UI 部品
functions/              Cloud Functions（TypeScript）
docs/                   正典ドキュメント（要件定義・詳細設計）
test/                   models / pages / services / widgets のテスト
.github/workflows/      CI・デプロイ
```

### models/ — データ構造

| ファイル | 概要 |
| --- | --- |
| `post.dart` | 投稿（`posts/{postId}`）。位置・画像・キャプション |
| `app_user.dart` | ユーザー（`users/{uid}`）。承認状態・ロールを持ち `toMap()` も提供 |
| `comment.dart` | 投稿へのコメント（`posts/{postId}/comments/{commentId}`） |
| `album.dart` | 投稿をテーマ単位でまとめるアルバム（`albums/{albumId}`） |
| `event.dart` | 参加表明できるイベント（`events/{eventId}`） |
| `release_note.dart` | `CHANGELOG.md` の 1 バージョン分のリリースノート |

### services/ — データアクセス層

いずれも Firebase インスタンスをコンストラクタで受け取る依存注入（DI）の形で、テストからモックを注入できます。

| ファイル | 概要 |
| --- | --- |
| `auth_service.dart` | サインイン・新規登録・サインアウトと認証状態の購読 |
| `user_service.dart` | ユーザー情報の購読、プロフィール更新・画像アップロード |
| `post_service.dart` | 投稿の CRUD、フィードのページング購読、ユーザー別投稿取得 |
| `comment_service.dart` | コメントの読み書き |
| `reaction_service.dart` | いいねの読み書き。ドキュメント ID を userId にして 1 ユーザー 1 件を保証 |
| `album_service.dart` | アルバムの読み書き。編集権限は Firestore ルールで担保 |
| `event_service.dart` | イベントの読み書きと参加表明 |
| `image_service.dart` | 投稿画像の検証・圧縮 |
| `location_service.dart` | 現在地取得と失敗理由の種別化 |
| `release_note_service.dart` | 同梱 `CHANGELOG.md` のパースと未読判定 |

### pages/ — 画面

| ファイル | 概要 |
| --- | --- |
| `auth/auth_gate.dart` | 認証・承認状態でルート画面を切り替えるゲート |
| `auth/login_page.dart` | ログイン画面 |
| `auth/register_page.dart` | 新規登録画面 |
| `auth/pending_approval_page.dart` | 管理者の承認待ち画面。承認されると自動で本体へ遷移 |
| `main_shell.dart` | 承認済みユーザーのアプリ本体。5 タブの `BottomNavigationBar` |
| `map_screen.dart` | 地図表示と地図タップでの投稿作成 |
| `feed_page.dart` | 投稿フィード |
| `post_detail_page.dart` | 投稿詳細（フルページ表示） |
| `album_list_page.dart` / `album_detail_page.dart` | アルバム一覧・詳細 |
| `event_page.dart` / `event_detail_page.dart` | イベント一覧・詳細 |
| `profile_page.dart` / `profile_edit_page.dart` | プロフィール表示・編集 |
| `release_notes_page.dart` | リリースお知らせ（変更履歴）一覧 |

### widgets/ — 再利用 UI

| ファイル | 概要 |
| --- | --- |
| `post_card.dart` | フィードの 1 投稿カード |
| `post_detail_view.dart` | 投稿詳細の中身。ページ版とダイアログ版で共通 |
| `post_widget.dart` | 投稿詳細のダイアログ表示。地図のマーカータップから開く |
| `post_add_dialog.dart` | 投稿作成ダイアログ |
| `comment_section.dart` | コメント一覧と投稿フォーム |
| `reaction_bar.dart` | いいね数とトグルボタン |
| `album_edit_dialog.dart` | アルバムの作成・編集ダイアログ |
| `event_edit_dialog.dart` | イベントの作成・編集ダイアログ |
| `event_schedule_text.dart` | イベント開催日時の整形表示 |
| `release_note_dialog.dart` | 更新後初回起動で出す「What's New」ダイアログ |
| `release_note_view.dart` | リリースノート本文の表示 |

### その他

| パス | 概要 |
| --- | --- |
| `functions/src/index.ts` | 登録承認フロー（Firestore トリガー + HTTPS）。リージョンは `asia-northeast2` |
| `firestore.rules` / `storage.rules` | Firestore・Storage のセキュリティルール |
| `docs/要件定義.md` / `docs/詳細設計.md` | 正典ドキュメント。実装で書き換えない |
| `CHANGELOG.md` | Keep a Changelog 形式。アプリ内リリースお知らせの元データ |
