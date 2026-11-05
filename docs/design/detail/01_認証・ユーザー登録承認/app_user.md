# lib/data/models/app_user.dart

| 項目 | 内容 |
|---|---|
| ファイル | `lib/data/models/app_user.dart` |
| 基本設計 | [01 認証・ユーザー登録承認](../../01_認証・ユーザー登録承認.md) の「4. データ設計」 |
| 関連する基本設計 | [09 プロフィール](../../09_プロフィール.md)、[04 コメント・リアクション](../../04_コメント・リアクション.md)、[05 アルバム](../../05_アルバム.md)、[06 イベント](../../06_イベント.md)、[07 コンテスト](../../07_コンテスト.md)、[08 通知](../../08_通知.md)（投稿者名・主催者名・権限判定の表示に使用） |
| レイヤ | Model |
| 主な依存先 | `package:cloud_firestore`（`Timestamp`） |
| 主な利用元 | `lib/data/repositories/auth_repository.dart`, `lib/data/repositories/user_repository.dart`, `lib/ui/auth/auth_gate.dart`, `lib/ui/profile/profile_page.dart`, `lib/ui/profile/profile_edit_page.dart`, `lib/ui/core/widgets/comment_section.dart`, `lib/ui/album/album_list_page.dart`, `lib/ui/album/album_detail_page.dart`, `lib/ui/event/event_page.dart`, `lib/ui/event/event_detail_page.dart`, `lib/ui/notification/notification_page.dart`, `lib/ui/post/post_detail_view_model.dart`, `lib/ui/post/widgets/post_detail_view.dart` |
| テスト | なし（専用のモデルテストは無い。`test/data/repositories/auth_repository_test.dart` が `toMap()` の書き込み結果を間接的に確認） |

## 1. 責務

Firestore `users/{uid}` の公開プロフィール 1 件を表すイミュータブルなデータクラス。

- Firestore のマップから `AppUser` を組み立てる（欠損フィールドは既定値で補う）。
- 新規登録時に `users/{uid}` へ書き込むマップを作る（`toMap()`）。
- 管理者かどうかの判定（`isAdmin`）を提供する。

メールアドレス等の個人情報は本クラスに含めない。それらは本人のみ読み書きできる `users/{uid}/private/profile` に分離して保持する（`users/{uid}` は投稿者名表示のためログイン済みユーザー全員に公開されるため）。

## 2. 構成要素（クラス・関数・定数の一覧）

| 種別 | 名前 | 概要 |
|---|---|---|
| クラス | `AppUser` | 公開プロフィールのデータクラス |
| ゲッター | `AppUser.isAdmin` | `role == 'admin'` |
| ファクトリ | `AppUser.fromSnapshot` | Firestore マップからの変換 |
| メソッド | `AppUser.toMap` | Firestore 書き込み用マップへの変換 |

ファイル内に定数は定義していない（ロール文字列 `'member'` / `'admin'` はリテラルで記述）。

## 3. 公開インターフェース（コンストラクタ引数・プロパティ・メソッドのシグネチャと説明）

### コンストラクタ

```dart
const AppUser({
  required this.id,
  required this.username,
  this.bio = '',
  this.profileImageUrl,
  this.role = 'member',
  this.approved = false,
  required this.createdAt,
});
```

### プロパティ

| 名前 | 型 | 既定値 | 説明 |
|---|---|---|---|
| `id` | `String` | 必須 | ユーザー UID（= ドキュメント ID） |
| `username` | `String` | 必須 | 表示名 |
| `bio` | `String` | `''` | 自己紹介 |
| `profileImageUrl` | `String?` | `null` | プロフィール画像のダウンロード URL |
| `role` | `String` | `'member'` | `'member'` または `'admin'` |
| `approved` | `bool` | `false` | 管理者承認済みか |
| `createdAt` | `DateTime` | 必須 | 登録日時 |
| `isAdmin` | `bool`（ゲッター） | — | `role == 'admin'` のとき `true` |

### メソッド

| シグネチャ | 説明 |
|---|---|
| `factory AppUser.fromSnapshot(String id, Map<String, dynamic> document)` | ドキュメント ID とデータマップから生成する |
| `Map<String, dynamic> toMap()` | 全フィールドを Firestore 書き込み用マップにする |

## 4. 内部状態（フィールド・状態遷移）

全フィールド `final` のイミュータブルクラスで、内部状態・状態遷移は持たない。
`approved` の `false → true` の遷移は Cloud Functions `handleApproval`（または管理者による Firestore 直接編集）がドキュメントを書き換えることで起こり、本クラスは新しいスナップショットから再生成される。

## 5. 処理詳細（メソッドごとの手順・分岐・呼び出す Repository/SDK）

### `AppUser.fromSnapshot(id, document)`

各フィールドを次の規則で取り出す。

| フィールド | 取り出し方 | 欠損時 |
|---|---|---|
| `id` | 引数 `id` をそのまま使う（マップ内の `id` は参照しない） | — |
| `username` | `document['username'] ?? ''` | `''` |
| `bio` | `document['bio'] ?? ''` | `''` |
| `profileImageUrl` | `document['profileImageUrl']`（そのまま代入） | `null` |
| `role` | `document['role'] ?? 'member'` | `'member'` |
| `approved` | `document['approved'] ?? false` | `false` |
| `createdAt` | `(document['createdAt'] as Timestamp?)?.toDate()` | `DateTime.now()` |

### `toMap()`

次のマップを返す。`profileImageUrl` が `null` の場合もキーは含め、値 `null` を書き込む。

```dart
{
  'id': id,
  'username': username,
  'bio': bio,
  'profileImageUrl': profileImageUrl,
  'role': role,
  'approved': approved,
  'createdAt': Timestamp.fromDate(createdAt),
}
```

現状 `toMap()` を呼ぶのは `AuthRepository.register` のみ（新規登録時の `users/{uid}` 作成）。

### `isAdmin`

`role == 'admin'` を返す。利用箇所は `ContestDetailPage`（管理者判定）と `PostDetailViewModel`（編集・削除権限判定）。

## 6. データ仕様（読み書きする Firestore/Storage のパス・フィールド、定数値）

対象ドキュメント: `users/{uid}`

| フィールド | Firestore 型 | Dart 型 | 備考 |
|---|---|---|---|
| `id` | string | `String` | `toMap()` で書き込む。読み取りではドキュメント ID を使う |
| `username` | string | `String` | |
| `bio` | string | `String` | |
| `profileImageUrl` | string / null | `String?` | Storage `profiles/{uid}/avatar.jpg` のダウンロード URL |
| `role` | string | `String` | `'member'` / `'admin'` |
| `approved` | bool | `bool` | |
| `createdAt` | Timestamp | `DateTime` | |

`email`・`emailNotification` は本ドキュメントに持たない（`users/{uid}/private/profile`、[auth_repository.md](auth_repository.md) 参照）。

## 7. 例外・エラー処理（例外の扱い・戻り値・表示メッセージ）

- 欠損フィールドは既定値で補うため、欠損では例外を投げない。
- 型の不一致（例: `username` が文字列以外、`createdAt` が `Timestamp` 以外）は `TypeError` になり、呼び出し元に伝播する。本クラスでは捕捉しない。

## 8. テスト観点（既存テストが確認していること / 未テストの観点）

既存テスト（間接）:

- `test/data/repositories/auth_repository_test.dart`: 登録後の `users/{uid}` に `username`、`approved: false`、`role: 'member'` が書かれ、`email` キーが無いこと（`toMap()` の内容）。
- `test/ui/core/post_card_test.dart`, `test/ui/post/post_detail_page_test.dart`: `role`・`approved`（`post_detail_page_test` では `createdAt` も）を欠いたドキュメントからでもユーザー名が表示されること（`fromSnapshot` の欠損補完）。

未テストの観点:

- `fromSnapshot` の各フィールドの既定値（特に `createdAt` 欠損時の `DateTime.now()`）。
- `isAdmin` の判定。
- `toMap()` → `fromSnapshot` の往復で値が保たれること。

## 9. 備考・既知の課題

- `createdAt` 欠損時に `DateTime.now()` を入れるため、読み取りのたびに値が変わる。表示や並べ替えに `createdAt` を使う場合は注意が要る。
- ロール文字列 `'member'` / `'admin'` が定数化されていない（`firestore.rules` 側とも文字列で一致させている）。
- `copyWith` は無い。プロフィール更新は `UserRepository.updateProfile` がフィールド単位で行う。
