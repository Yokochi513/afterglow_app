# 詳細設計書（ファイル単位）— afterglow_app

**作成日**: 2026-11-05
**作成方法**: 現行コードからの逆起こし

本ディレクトリは、[基本設計書（機能別）](../README.md) の各書に紐づく詳細設計書を、**ソースファイル 1 つにつき 1 文書**で記述したものである。
基本設計書が「機能として何をするか」を示すのに対し、詳細設計書は「そのファイルのクラス・メソッドが具体的にどう動くか」を示す。

- 各ソースファイルは、主に属する基本設計書 1 つに割り当て、そのフォルダに置く。複数の機能から使われるファイル（例: `PostRepository`）は文書冒頭の「関連する基本設計」に他の基本設計書を列挙する。
- ファイル名は `<ソースファイル名（拡張子なし）>.md` とする（例: `lib/data/repositories/post_repository.dart` → `post_repository.md`）。
- 生成物 `lib/firebase_options.dart` は対象外とする。
- コードと本書に差異がある場合はコードが正である。差異を見つけたら本書を更新する。

## 文書一覧

### [00 システム概要・共通設計](../00_システム概要.md) → [00_システム概要/](00_システム概要/)

| ソースファイル | 詳細設計書 |
|---|---|
| `lib/main.dart` | [main.md](00_システム概要/main.md) |
| `lib/app/app.dart` | [app.md](00_システム概要/app.md) |
| `lib/app/dependencies.dart` | [dependencies.md](00_システム概要/dependencies.md) |
| `lib/app/main_shell.dart` | [main_shell.md](00_システム概要/main_shell.md) |
| `functions/src/index.ts` | [functions_index.md](00_システム概要/functions_index.md) |
| `firestore.rules` | [firestore_rules.md](00_システム概要/firestore_rules.md) |
| `storage.rules` | [storage_rules.md](00_システム概要/storage_rules.md) |

### [01 認証・ユーザー登録承認](../01_認証・ユーザー登録承認.md) → [01_認証・ユーザー登録承認/](01_認証・ユーザー登録承認/)

| ソースファイル | 詳細設計書 |
|---|---|
| `lib/data/models/app_user.dart` | [app_user.md](01_認証・ユーザー登録承認/app_user.md) |
| `lib/data/repositories/auth_repository.dart` | [auth_repository.md](01_認証・ユーザー登録承認/auth_repository.md) |
| `lib/data/repositories/user_repository.dart` | [user_repository.md](01_認証・ユーザー登録承認/user_repository.md) |
| `lib/ui/auth/auth_gate.dart` | [auth_gate.md](01_認証・ユーザー登録承認/auth_gate.md) |
| `lib/ui/auth/login_page.dart` | [login_page.md](01_認証・ユーザー登録承認/login_page.md) |
| `lib/ui/auth/register_page.dart` | [register_page.md](01_認証・ユーザー登録承認/register_page.md) |
| `lib/ui/auth/pending_approval_page.dart` | [pending_approval_page.md](01_認証・ユーザー登録承認/pending_approval_page.md) |

### [02 地図・投稿作成](../02_地図・投稿作成.md) → [02_地図・投稿作成/](02_地図・投稿作成/)

| ソースファイル | 詳細設計書 |
|---|---|
| `lib/data/models/post.dart` | [post.md](02_地図・投稿作成/post.md) |
| `lib/data/repositories/post_repository.dart` | [post_repository.md](02_地図・投稿作成/post_repository.md) |
| `lib/data/services/image_service.dart` | [image_service.md](02_地図・投稿作成/image_service.md) |
| `lib/data/services/location_service.dart` | [location_service.md](02_地図・投稿作成/location_service.md) |
| `lib/data/services/geocoding_service.dart` | [geocoding_service.md](02_地図・投稿作成/geocoding_service.md) |
| `lib/ui/map/map_screen.dart` | [map_screen.md](02_地図・投稿作成/map_screen.md) |
| `lib/ui/map/location_picker_page.dart` | [location_picker_page.md](02_地図・投稿作成/location_picker_page.md) |
| `lib/ui/map/widgets/map_search_bar.dart` | [map_search_bar.md](02_地図・投稿作成/map_search_bar.md) |
| `lib/ui/map/widgets/post_location_confirm_bar.dart` | [post_location_confirm_bar.md](02_地図・投稿作成/post_location_confirm_bar.md) |
| `lib/ui/post/post_add_dialog.dart` | [post_add_dialog.md](02_地図・投稿作成/post_add_dialog.md) |
| `lib/ui/post/post_add_view_model.dart` | [post_add_view_model.md](02_地図・投稿作成/post_add_view_model.md) |
| `lib/ui/post/photo_location_suggestion.dart` | [photo_location_suggestion.md](02_地図・投稿作成/photo_location_suggestion.md) |

### [03 フィード・投稿詳細](../03_フィード・投稿詳細.md) → [03_フィード・投稿詳細/](03_フィード・投稿詳細/)

| ソースファイル | 詳細設計書 |
|---|---|
| `lib/ui/feed/feed_page.dart` | [feed_page.md](03_フィード・投稿詳細/feed_page.md) |
| `lib/ui/core/widgets/post_card.dart` | [post_card.md](03_フィード・投稿詳細/post_card.md) |
| `lib/ui/post/post_detail_page.dart` | [post_detail_page.md](03_フィード・投稿詳細/post_detail_page.md) |
| `lib/ui/post/post_detail_view_model.dart` | [post_detail_view_model.md](03_フィード・投稿詳細/post_detail_view_model.md) |
| `lib/ui/post/widgets/post_detail_view.dart` | [post_detail_view.md](03_フィード・投稿詳細/post_detail_view.md) |
| `lib/ui/post/widgets/post_widget.dart` | [post_widget.md](03_フィード・投稿詳細/post_widget.md) |
| `lib/ui/post/image_viewer_page.dart` | [image_viewer_page.md](03_フィード・投稿詳細/image_viewer_page.md) |

### [04 コメント・リアクション](../04_コメント・リアクション.md) → [04_コメント・リアクション/](04_コメント・リアクション/)

| ソースファイル | 詳細設計書 |
|---|---|
| `lib/data/models/comment.dart` | [comment.md](04_コメント・リアクション/comment.md) |
| `lib/data/repositories/comment_repository.dart` | [comment_repository.md](04_コメント・リアクション/comment_repository.md) |
| `lib/data/repositories/reaction_repository.dart` | [reaction_repository.md](04_コメント・リアクション/reaction_repository.md) |
| `lib/ui/core/widgets/comment_section.dart` | [comment_section.md](04_コメント・リアクション/comment_section.md) |
| `lib/ui/core/widgets/reaction_bar.dart` | [reaction_bar.md](04_コメント・リアクション/reaction_bar.md) |

### [05 アルバム](../05_アルバム.md) → [05_アルバム/](05_アルバム/)

| ソースファイル | 詳細設計書 |
|---|---|
| `lib/data/models/album.dart` | [album.md](05_アルバム/album.md) |
| `lib/data/repositories/album_repository.dart` | [album_repository.md](05_アルバム/album_repository.md) |
| `lib/ui/album/album_list_page.dart` | [album_list_page.md](05_アルバム/album_list_page.md) |
| `lib/ui/album/album_detail_page.dart` | [album_detail_page.md](05_アルバム/album_detail_page.md) |
| `lib/ui/album/widgets/album_edit_dialog.dart` | [album_edit_dialog.md](05_アルバム/album_edit_dialog.md) |

### [06 イベント](../06_イベント.md) → [06_イベント/](06_イベント/)

| ソースファイル | 詳細設計書 |
|---|---|
| `lib/data/models/event.dart` | [event.md](06_イベント/event.md) |
| `lib/data/repositories/event_repository.dart` | [event_repository.md](06_イベント/event_repository.md) |
| `lib/ui/event/event_page.dart` | [event_page.md](06_イベント/event_page.md) |
| `lib/ui/event/event_detail_page.dart` | [event_detail_page.md](06_イベント/event_detail_page.md) |
| `lib/ui/event/widgets/event_edit_dialog.dart` | [event_edit_dialog.md](06_イベント/event_edit_dialog.md) |
| `lib/ui/core/widgets/event_schedule_text.dart` | [event_schedule_text.md](06_イベント/event_schedule_text.md) |

### [07 コンテスト](../07_コンテスト.md) → [07_コンテスト/](07_コンテスト/)

| ソースファイル | 詳細設計書 |
|---|---|
| `lib/data/models/contest.dart` | [contest.md](07_コンテスト/contest.md) |
| `lib/data/repositories/contest_repository.dart` | [contest_repository.md](07_コンテスト/contest_repository.md) |
| `lib/ui/contest/contest_list_page.dart` | [contest_list_page.md](07_コンテスト/contest_list_page.md) |
| `lib/ui/contest/contest_detail_page.dart` | [contest_detail_page.md](07_コンテスト/contest_detail_page.md) |
| `lib/ui/contest/widgets/contest_edit_dialog.dart` | [contest_edit_dialog.md](07_コンテスト/contest_edit_dialog.md) |
| `lib/ui/core/widgets/contest_entry_badge.dart` | [contest_entry_badge.md](07_コンテスト/contest_entry_badge.md) |

### [08 通知](../08_通知.md) → [08_通知/](08_通知/)

| ソースファイル | 詳細設計書 |
|---|---|
| `lib/data/models/notification.dart` | [notification.md](08_通知/notification.md) |
| `lib/data/repositories/notification_repository.dart` | [notification_repository.md](08_通知/notification_repository.md) |
| `lib/data/services/push_notification_service.dart` | [push_notification_service.md](08_通知/push_notification_service.md) |
| `lib/ui/notification/notification_page.dart` | [notification_page.md](08_通知/notification_page.md) |
| `lib/ui/notification/widgets/notification_bell.dart` | [notification_bell.md](08_通知/notification_bell.md) |

### [09 プロフィール](../09_プロフィール.md) → [09_プロフィール/](09_プロフィール/)

| ソースファイル | 詳細設計書 |
|---|---|
| `lib/ui/profile/profile_page.dart` | [profile_page.md](09_プロフィール/profile_page.md) |
| `lib/ui/profile/profile_edit_page.dart` | [profile_edit_page.md](09_プロフィール/profile_edit_page.md) |

### [10 お知らせ・使い方ガイド・フィードバック](../10_お知らせ・使い方ガイド.md) → [10_お知らせ・使い方ガイド/](10_お知らせ・使い方ガイド/)

| ソースファイル | 詳細設計書 |
|---|---|
| `lib/data/models/release_note.dart` | [release_note.md](10_お知らせ・使い方ガイド/release_note.md) |
| `lib/data/repositories/release_note_repository.dart` | [release_note_repository.md](10_お知らせ・使い方ガイド/release_note_repository.md) |
| `lib/data/repositories/usage_guide_repository.dart` | [usage_guide_repository.md](10_お知らせ・使い方ガイド/usage_guide_repository.md) |
| `lib/ui/info/release_notes_page.dart` | [release_notes_page.md](10_お知らせ・使い方ガイド/release_notes_page.md) |
| `lib/ui/info/usage_guide_page.dart` | [usage_guide_page.md](10_お知らせ・使い方ガイド/usage_guide_page.md) |
| `lib/ui/info/widgets/release_note_dialog.dart` | [release_note_dialog.md](10_お知らせ・使い方ガイド/release_note_dialog.md) |
| `lib/ui/info/widgets/release_note_view.dart` | [release_note_view.md](10_お知らせ・使い方ガイド/release_note_view.md) |
| `lib/ui/info/widgets/usage_guide_dialog.dart` | [usage_guide_dialog.md](10_お知らせ・使い方ガイド/usage_guide_dialog.md) |
| `lib/ui/info/widgets/usage_guide_view.dart` | [usage_guide_view.md](10_お知らせ・使い方ガイド/usage_guide_view.md) |

## 各書の構成

各詳細設計書は次の構成で記述する（該当しない節は「なし」と書いて残す）。

```markdown
# <ソースファイルの相対パス>

| 項目 | 内容 |
|---|---|
| ファイル | `lib/...` |
| 基本設計 | [NN 機能名](../../NN_機能名.md) の該当節 |
| 関連する基本設計 | 他に使われる機能の基本設計書（無ければ「なし」） |
| レイヤ | View / ViewModel / Repository / Service / Model / App / Functions / Rules |
| 主な依存先 | import しているプロジェクト内ファイル・主要パッケージ |
| 主な利用元 | このファイルを使うプロジェクト内ファイル |
| テスト | 対応するテストファイル（無ければ「なし」） |

## 1. 責務
## 2. 構成要素（クラス・関数・定数の一覧）
## 3. 公開インターフェース（コンストラクタ引数・プロパティ・メソッドのシグネチャと説明）
## 4. 内部状態（フィールド・状態遷移）
## 5. 処理詳細（メソッドごとの手順・分岐・呼び出す Repository/SDK）
## 6. データ仕様（読み書きする Firestore/Storage のパス・フィールド、定数値）
## 7. 例外・エラー処理（例外の扱い・戻り値・表示メッセージ）
## 8. テスト観点（既存テストが確認していること / 未テストの観点）
## 9. 備考・既知の課題
```
