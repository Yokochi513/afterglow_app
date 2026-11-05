# lib/data/repositories/user_repository.dart

| 項目 | 内容 |
|---|---|
| ファイル | `lib/data/repositories/user_repository.dart` |
| 基本設計 | [01 認証・ユーザー登録承認](../../01_認証・ユーザー登録承認.md) の「2. AuthGate の切り替え条件」「4. データ設計」 |
| 関連する基本設計 | [09 プロフィール](../../09_プロフィール.md)（表示・更新・画像アップロード）、[03 フィード・投稿詳細](../../03_フィード・投稿詳細.md)・[04 コメント・リアクション](../../04_コメント・リアクション.md)・[05 アルバム](../../05_アルバム.md)・[06 イベント](../../06_イベント.md)・[07 コンテスト](../../07_コンテスト.md)・[08 通知](../../08_通知.md)（ユーザー名表示・管理者判定） |
| レイヤ | Repository |
| 主な依存先 | `lib/data/models/app_user.dart`、`package:cloud_firestore`、`package:firebase_storage`、`package:image_picker`（`XFile`） |
| 主な利用元 | `lib/app/dependencies.dart`（生成・提供）, `lib/ui/auth/auth_gate.dart`, `lib/ui/profile/profile_page.dart`, `lib/ui/profile/profile_edit_page.dart`, `lib/ui/core/widgets/post_card.dart`, `lib/ui/core/widgets/comment_section.dart`, `lib/ui/album/album_list_page.dart`, `lib/ui/album/album_detail_page.dart`, `lib/ui/event/event_page.dart`, `lib/ui/event/event_detail_page.dart`, `lib/ui/contest/contest_detail_page.dart`, `lib/ui/notification/notification_page.dart`, `lib/ui/post/post_detail_view_model.dart` |
| テスト | 専用テストなし。`test/ui/core/post_card_test.dart`, `test/ui/post/post_detail_page_test.dart`, `test/ui/post/post_detail_view_model_test.dart` が実インスタンス（`FakeFirebaseFirestore` + `MockFirebaseStorage`）を使う |

## 1. 責務

`users/{uid}` 公開プロフィールの読み取り・更新と、プロフィール画像の Storage アップロードを担う。

- 1 ユーザーの購読（`watchUser`）: `AuthGate` の承認検知、各画面のユーザー名・アバター表示に使う。
- 1 ユーザーの単発取得（`getUser`）: 管理者判定・通知の行為者表示に使う。
- プロフィール更新（`updateProfile`）と画像アップロード（`uploadProfileImage`）: `ProfileEditPage` から使う。

ユーザーの新規作成は [AuthRepository.register](auth_repository.md) が行う。

## 2. 構成要素（クラス・関数・定数の一覧）

| 種別 | 名前 | 概要 |
|---|---|---|
| クラス | `UserRepository` | ユーザーリポジトリ |
| 定数 | `UserRepository.usersCollection` | `'users'` |
| メソッド | `watchUser` / `getUser` | 読み取り |
| メソッド | `updateProfile` / `uploadProfileImage` | 更新 |

## 3. 公開インターフェース（コンストラクタ引数・プロパティ・メソッドのシグネチャと説明）

### コンストラクタ

```dart
UserRepository({FirebaseFirestore? firestore, FirebaseStorage? storage})
```

| 引数 | 既定値 | 説明 |
|---|---|---|
| `firestore` | `FirebaseFirestore.instance` | |
| `storage` | `FirebaseStorage.instance` | |

### メソッド

| シグネチャ | 説明 |
|---|---|
| `Stream<AppUser?> watchUser(String uid)` | `users/{uid}` を購読。ドキュメントが無ければ `null` を流す |
| `Future<AppUser?> getUser(String uid)` | `users/{uid}` を 1 回取得。無ければ `null` |
| `Future<void> updateProfile(String uid, {required String username, required String bio, String? profileImageUrl})` | `username`・`bio`・（指定時のみ）`profileImageUrl` を更新 |
| `Future<String> uploadProfileImage(String uid, XFile imageFile)` | `profiles/{uid}/avatar.jpg` にアップロードしダウンロード URL を返す |

## 4. 内部状態（フィールド・状態遷移）

| フィールド | 型 | 説明 |
|---|---|---|
| `_firestore` | `FirebaseFirestore`（final） | |
| `_storage` | `FirebaseStorage`（final） | |

可変状態は持たない。`watchUser` は呼ぶたびに新しい `Stream` を返す（キャッシュしない）。

## 5. 処理詳細（メソッドごとの手順・分岐・呼び出す Repository/SDK）

### `watchUser(uid)`

1. `_firestore.collection('users').doc(uid).snapshots()` を購読する。
2. 各スナップショットを `map` で変換する。
   - `snapshot.data()` が `null`（ドキュメント不存在）なら `null`。
   - それ以外は `AppUser.fromSnapshot(snapshot.id, data)`。

承認時に `handleApproval` が `approved: true` に更新すると、新しいスナップショットが流れ `AuthGate` が `MainShell` に切り替わる。

### `getUser(uid)`

1. `_firestore.collection('users').doc(uid).get()` を待つ。
2. `data()` が `null` なら `null`、それ以外は `AppUser.fromSnapshot(snapshot.id, data)` を返す。

### `updateProfile(uid, {username, bio, profileImageUrl})`

1. `users/{uid}` に `update` で次のマップを書く。

   ```dart
   {
     'username': username,
     'bio': bio,
     'profileImageUrl': ?profileImageUrl, // null-aware 要素
   }
   ```

2. `'profileImageUrl': ?profileImageUrl` は Dart の null-aware マップ要素で、`profileImageUrl` が `null` のときはキー自体を含めない。したがって画像を選ばなかった保存では既存の画像 URL を変更しない（`null` で消すこともしない）。
3. `update` の `Future` をそのまま返す。

`approved`・`role` は書き込まないため、`firestore.rules` の本人更新条件（`approved`/`role` 不変）を満たす。

### `uploadProfileImage(uid, imageFile)`

1. 参照 `_storage.ref().child('profiles/$uid/avatar.jpg')` を作る。
2. `imageFile.readAsBytes()` でバイト列を読み、`putData(bytes, SettableMetadata(contentType: 'image/jpeg'))` でアップロードし完了を待つ。
3. `uploadTask.ref.getDownloadURL()` を返す。

ファイル名は固定のため、毎回同じパスに上書きする。画像の縮小は呼び出し元（`ProfileEditPage` の `ImagePicker` 指定: 最大 800×800・品質 85）で行い、本メソッドでは圧縮しない。

## 6. データ仕様（読み書きする Firestore/Storage のパス・フィールド、定数値）

| 対象 | パス | 操作 | フィールド / 内容 |
|---|---|---|---|
| Firestore | `users/{uid}` | 読取（`watchUser`, `getUser`） | 全フィールド（[app_user.md](app_user.md)） |
| Firestore | `users/{uid}` | 更新（`updateProfile`） | `username`, `bio`, `profileImageUrl`（指定時のみ） |
| Storage | `profiles/{uid}/avatar.jpg` | 書込（`uploadProfileImage`） | Content-Type `image/jpeg` |

| 定数 | 値 |
|---|---|
| `usersCollection` | `'users'` |
| Storage パス | `'profiles/$uid/avatar.jpg'`（リテラル） |
| Content-Type | `'image/jpeg'`（リテラル） |

## 7. 例外・エラー処理（例外の扱い・戻り値・表示メッセージ）

本クラスは例外を捕捉しない。

| メソッド | 失敗時 | 呼び出し元の扱い |
|---|---|---|
| `watchUser` | ストリームに error が流れる | `AuthGate`/`ProfilePage` 等は `snapshot.data` が `null` として扱う（エラー専用表示は無い） |
| `getUser` | 例外を投げる | 呼び出し元ごと（`ContestDetailPage`・`PostDetailViewModel`・`NotificationPage`） |
| `updateProfile` | 例外を投げる（ドキュメント不存在時の `not-found` を含む） | `ProfileEditPage` が「更新に失敗しました」 |
| `uploadProfileImage` | 例外を投げる（10MB 以上・ルール拒否等） | 同上 |

「ドキュメントが存在しない」は例外ではなく `null` で表す（`watchUser`/`getUser`）。

## 8. テスト観点（既存テストが確認していること / 未テストの観点）

既存テスト（間接）:

- `test/ui/core/post_card_test.dart`, `test/ui/post/post_detail_page_test.dart`: `watchUser` 経由で投稿者のユーザー名が表示されること。
- `test/ui/post/post_detail_view_model_test.dart`: `getUser` による管理者判定を含む編集・削除権限。

未テストの観点:

- `watchUser`/`getUser` のドキュメント不存在時の `null`。
- `updateProfile` で `profileImageUrl` 省略時にキーが書かれないこと。
- `uploadProfileImage` のパス・Content-Type・返す URL。

## 9. 備考・既知の課題

- Content-Type が常に `image/jpeg`（PNG 等もこの指定で保存される）。基本設計 09 の 7 章に記載済み。
- 固定ファイル名で上書きするため、古い画像がキャッシュから表示されうる（基本設計 09 の 7 章）。
- Repository が `image_picker` の `XFile` に依存しており、データ層が UI 寄りのパッケージ型を受け取っている。
- `usersCollection` は `AuthRepository.usersCollection` と重複定義。
