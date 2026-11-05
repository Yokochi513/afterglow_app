# lib/data/repositories/album_repository.dart

| 項目 | 内容 |
|---|---|
| ファイル | `lib/data/repositories/album_repository.dart` |
| 基本設計 | [05 アルバム](../../05_アルバム.md) の「3. 処理フロー」「4. データ設計」「5. 権限・セキュリティ」 |
| 関連する基本設計 | なし |
| レイヤ | Repository |
| 主な依存先 | `lib/data/models/album.dart`, `package:cloud_firestore` |
| 主な利用元 | `lib/app/dependencies.dart`（生成・提供）, `lib/ui/album/album_list_page.dart`, `lib/ui/album/album_detail_page.dart`, `lib/ui/album/widgets/album_edit_dialog.dart` |
| テスト | `test/data/repositories/album_repository_test.dart`、ルールは `test/rules/users.test.mjs`（未承認は `albums` を読めない／承認後は読める） |

## 1. 責務

`albums` コレクションに対する作成・一覧購読・所有者別購読・単一購読・投稿の出し入れ・タイトル等の更新・削除を提供する。所有者判定 `isOwnedBy` を公開し、UI が所有者向け操作の出し分けに使う。権限の強制は Firestore ルールが担う。

## 2. 構成要素（クラス・関数・定数の一覧）

| 名前 | 種別 | 値・概要 |
|---|---|---|
| `AlbumRepository` | クラス | アルバムのデータアクセス |
| `albumsCollection` | `static const String` | `'albums'` |
| `_albumsRef` | private getter | `albums` の `CollectionReference` |
| `createAlbum` / `getAlbums` / `getUserAlbums` / `watchAlbum` / `addPost` / `removePost` / `updateAlbum` / `deleteAlbum` / `isOwnedBy` | 公開メソッド | 後述 |

## 3. 公開インターフェース（コンストラクタ引数・プロパティ・メソッドのシグネチャと説明）

```dart
AlbumRepository({FirebaseFirestore? firestore})
```

`firestore` 省略時は `FirebaseFirestore.instance`。

| シグネチャ | 戻り値 | 説明 |
|---|---|---|
| `Future<String?> createAlbum(Album album)` | 作成 ID / 失敗時 `null` | `album.id` が空なら自動採番 |
| `Stream<List<Album>> getAlbums()` | 全アルバム | `createdAt` 降順 |
| `Stream<List<Album>> getUserAlbums(String ownerId)` | 所有者のアルバム | クライアント側で `createdAt` 降順に並べ替え |
| `Stream<Album?> watchAlbum(String albumId)` | 単一アルバム | 存在しなければ `null` |
| `Future<bool> addPost(String albumId, String postId)` | 成否 | `arrayUnion` で追加 |
| `Future<bool> removePost(String albumId, String postId)` | 成否 | `arrayRemove` で除去 |
| `Future<bool> updateAlbum(String albumId, {required String title, required String description, String? coverImageUrl})` | 成否 | `coverImageUrl` は指定時のみ更新 |
| `Future<bool> deleteAlbum(String albumId)` | 成否 | アルバムのみ削除（投稿は消さない） |
| `bool isOwnedBy(Album album, String? uid)` | 所有者か | `uid != null && album.ownerId == uid` |

## 4. 内部状態（フィールド・状態遷移）

| フィールド | 型 | 内容 |
|---|---|---|
| `_firestore` | `FirebaseFirestore`（final） | 注入されたインスタンス |

状態遷移なし。

## 5. 処理詳細（メソッドごとの手順・分岐・呼び出す Repository/SDK）

### `createAlbum(album)`

1. `album.id.isEmpty` なら `_albumsRef.doc()`（自動採番）、そうでなければ `_albumsRef.doc(album.id)`。
2. `docRef.set(album.toMap())`。
3. 成功で `docRef.id` を返す。例外時は `null`。

### `getAlbums()`

`_albumsRef.orderBy('createdAt', descending: true).snapshots()` を購読し、各ドキュメントを `Album.fromSnapshot` で変換して `toList(growable: false)`。

### `getUserAlbums(ownerId)`

1. `_albumsRef.where('ownerId', isEqualTo: ownerId).snapshots()` を購読する（`orderBy` を付けず複合インデックスを不要にする）。
2. 変換後のリストを `b.createdAt.compareTo(a.createdAt)` で降順ソートして返す（`PostRepository.getUserPosts` と同じ方針）。

### `watchAlbum(albumId)`

`_albumsRef.doc(albumId).snapshots()` を購読し、`snapshot.data()` が null（ドキュメントなし・削除後）なら `null`、それ以外は `Album.fromSnapshot(snapshot.id, data)` を流す。

### `addPost(albumId, postId)`

`_albumsRef.doc(albumId).update({'postIds': FieldValue.arrayUnion([postId])})`。既に含まれる ID は重複しない。新規要素は配列末尾に付く。成功で `true`、例外時 `false`。

### `removePost(albumId, postId)`

`update({'postIds': FieldValue.arrayRemove([postId])})`。投稿ドキュメントは削除しない。成功で `true`、例外時 `false`。

### `updateAlbum(albumId, {title, description, coverImageUrl})`

1. `update` するマップは `{'title': title, 'description': description, 'coverImageUrl': ?coverImageUrl}`。
2. `?coverImageUrl` は Dart の null-aware 要素で、`coverImageUrl` が null のときはキーごと省略される。したがって省略時はカバー画像を変更せず、null で消去することもできない。
3. 成功で `true`、例外時 `false`。

### `deleteAlbum(albumId)`

`_albumsRef.doc(albumId).delete()`。含まれる投稿は削除しない。成功で `true`、例外時 `false`。

### `isOwnedBy(album, uid)`

`uid != null && album.ownerId == uid`。ルールの所有者条件を UI 側で先回りする判定で、管理者は含めない。

## 6. データ仕様（読み書きする Firestore/Storage のパス・フィールド、定数値）

| パス | 操作 | フィールド |
|---|---|---|
| `albums/{albumId}` | 作成（`set`） | `ownerId`, `title`, `description`, `postIds`, `coverImageUrl`（null 含む）, `createdAt` |
| 同上 | 読取（一覧・単一・所有者別） | 全フィールド |
| 同上 | 更新 | `postIds`（`arrayUnion` / `arrayRemove`）、`title`, `description`, `coverImageUrl`（指定時のみ） |
| 同上 | 削除 | — |

クエリ: `getAlbums` は `orderBy('createdAt', desc)`、`getUserAlbums` は `where('ownerId', ==)` のみ。

ルール: 読取は承認済み、作成は承認済みかつ `request.resource.data.ownerId == auth.uid`、更新・削除は承認済みかつ（`resource.data.ownerId == auth.uid` または管理者）。

## 7. 例外・エラー処理（例外の扱い・戻り値・表示メッセージ）

- 書き込み系はすべて `catch (_)` で例外を握りつぶし、`createAlbum` は `null`、その他は `false` を返す。ログ出力はない。メッセージは呼び出し側が出す。
- 存在しないアルバムへの `update`（`addPost` / `removePost` / `updateAlbum`）は `not-found` で `false`。`delete` は存在しなくても成功扱い。
- 購読系は例外を捕捉せず Stream のエラーとして流す。

## 8. テスト観点（既存テストが確認していること / 未テストの観点）

既存（`album_repository_test.dart`）:
- `createAlbum` が保存して採番 ID を返す／指定 ID を使う。
- `getAlbums` が全ユーザーのアルバムを `createdAt` 降順で返す。
- `getUserAlbums` が所有者に限定され新しい順に並ぶ。
- `watchAlbum` がアルバムを流し、存在しないと `null`。
- `addPost` が重複なく追加、`removePost` が指定 ID だけ除去。
- `updateAlbum` がタイトル・説明を変更し、カバー省略時は保持する。
- `deleteAlbum` で削除される。
- `isOwnedBy` が所有者 UID のときだけ true。

既存（ルール）: `test/rules/users.test.mjs` で未承認ユーザーが `albums` を読めず、承認後に読めること。

未テスト: 書き込み失敗時の戻り値、作成時の `ownerId` 偽装拒否・他人の更新拒否のルールテスト。

## 9. 備考・既知の課題

- `getUserAlbums` は `lib/` 内に呼び出し元がない（テストのみ）。
- 投稿を削除しても `postIds` に ID が残る。表示側（`AlbumDetailPage`）で除外するが件数には含まれる（基本設計 7 章）。
- `isOwnedBy` は管理者を考慮しないため、ルール上可能な管理者による他人アルバムの編集は UI から行えない。
