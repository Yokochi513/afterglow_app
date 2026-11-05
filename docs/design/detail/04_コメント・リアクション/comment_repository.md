# lib/data/repositories/comment_repository.dart

| 項目 | 内容 |
|---|---|
| ファイル | `lib/data/repositories/comment_repository.dart` |
| 基本設計 | [04 コメント・リアクション](../../04_コメント・リアクション.md) の「3.1 コメント」「4. データ設計」 |
| 関連する基本設計 | [03 フィード・投稿詳細](../../03_フィード・投稿詳細.md)（`PostCard` のコメント件数表示）、[08 通知](../../08_通知.md)（作成がトリガー） |
| レイヤ | Repository |
| 主な依存先 | `lib/data/models/comment.dart`, `package:cloud_firestore` |
| 主な利用元 | `lib/app/dependencies.dart`（生成・提供）, `lib/ui/core/widgets/comment_section.dart`, `lib/ui/core/widgets/post_card.dart`（`getCommentCount`） |
| テスト | `test/data/repositories/comment_repository_test.dart`、ルールは `test/rules/posts.test.mjs`「コメント（Issue #58 / #59）」 |

## 1. 責務

`posts/{postId}/comments` サブコレクションに対するコメントの購読・件数購読・追加・本文更新・削除を提供する。権限（本人のみ更新・削除）は Firestore ルールで担保し、本クラスは判定しない。

## 2. 構成要素（クラス・関数・定数の一覧）

| 名前 | 種別 | 概要 |
|---|---|---|
| `CommentRepository` | クラス | コメントのデータアクセス |
| `postsCollection` | `static const String` | `'posts'` |
| `commentsCollection` | `static const String` | `'comments'` |
| `_commentsRef(String postId)` | private メソッド | `posts/{postId}/comments` の `CollectionReference` を返す |
| `getComments` / `getCommentCount` / `addComment` / `updateComment` / `deleteComment` | 公開メソッド | 後述 |

## 3. 公開インターフェース（コンストラクタ引数・プロパティ・メソッドのシグネチャと説明）

### コンストラクタ

```dart
CommentRepository({FirebaseFirestore? firestore})
```

`firestore` 省略時は `FirebaseFirestore.instance`。テストでは `FakeFirebaseFirestore` を注入する。

### メソッド

| シグネチャ | 戻り値 | 説明 |
|---|---|---|
| `Stream<List<Comment>> getComments(String postId)` | コメント一覧の Stream | `createdAt` 昇順（古い順）で購読 |
| `Stream<int> getCommentCount(String postId)` | 件数の Stream | サブコレクションのドキュメント数を購読 |
| `Future<bool> addComment(Comment comment)` | 成否 | `comment.id` が空なら自動採番して作成 |
| `Future<bool> updateComment(String postId, String commentId, String text)` | 成否 | 本文と `updatedAt` を更新 |
| `Future<bool> deleteComment(String postId, String commentId)` | 成否 | コメントを削除 |

## 4. 内部状態（フィールド・状態遷移）

| フィールド | 型 | 内容 |
|---|---|---|
| `_firestore` | `FirebaseFirestore`（final） | 注入されたインスタンス |

状態遷移はない（ステートレス）。

## 5. 処理詳細（メソッドごとの手順・分岐・呼び出す Repository/SDK）

### `_commentsRef(postId)`

`_firestore.collection('posts').doc(postId).collection('comments')` を返す。

### `getComments(postId)`

1. `_commentsRef(postId).orderBy('createdAt', descending: false).snapshots()` を購読する。
2. 各スナップショットの `docs` を `Comment.fromSnapshot(doc.id, doc.data())` で変換し、`toList(growable: false)` で返す。

### `getCommentCount(postId)`

1. `_commentsRef(postId).snapshots()` を購読する（並べ替えなし）。
2. `snapshot.docs.length` を流す。
3. `posts/{postId}.commentCount` の非正規化カウントは使わない。コメント投稿者は他人の投稿ドキュメントを更新できず、`commentCount` は作成時の 0 から変わらないため（Issue #58 / #59）。

### `addComment(comment)`

1. `collection = _commentsRef(comment.postId)`。
2. `comment.id.isEmpty` なら `collection.doc()`（自動採番）、そうでなければ `collection.doc(comment.id)`。
3. `docRef.set(comment.toMap())` を待つ。
4. 成功で `true`。例外はすべて捕捉して `false`。

作成をトリガーに Functions `onCommentCreated` が投稿者へ通知を作る（クライアント側の処理ではない）。

### `updateComment(postId, commentId, text)`

1. `_commentsRef(postId).doc(commentId).update({...})` を実行する。更新内容は `'text': text` と `'updatedAt': Timestamp.fromDate(DateTime.now())`（クライアント時刻）。
2. 成功で `true`、例外時は `false`。

### `deleteComment(postId, commentId)`

1. `_commentsRef(postId).doc(commentId).delete()`。
2. 成功で `true`、例外時は `false`。

## 6. データ仕様（読み書きする Firestore/Storage のパス・フィールド、定数値）

| パス | 操作 | フィールド |
|---|---|---|
| `posts/{postId}/comments/{commentId}` | 読取（購読） | 全フィールド（`Comment.fromSnapshot`） |
| 同上 | 作成（`set`） | `postId`, `userId`, `text`, `createdAt`（`updatedAt` は通常含まれない） |
| 同上 | 更新（`update`） | `text`, `updatedAt` |
| 同上 | 削除 | — |

並び順: `createdAt` 昇順。複合インデックスは不要（単一フィールドの `orderBy` のみ）。

ルール（`firestore.rules`）: 読取は承認済み、作成は承認済みかつ `request.resource.data.userId == request.auth.uid`、更新・削除は承認済みかつ（`resource.data.userId == auth.uid` または管理者）。

## 7. 例外・エラー処理（例外の扱い・戻り値・表示メッセージ）

- 書き込み系（`addComment` / `updateComment` / `deleteComment`）は `catch (_)` で全例外を捕捉し `false` を返す。例外内容はログにも残さない。表示メッセージは呼び出し側（`CommentSection`）が出す。
- 購読系（`getComments` / `getCommentCount`）は例外を捕捉しない。ルール拒否などのエラーは Stream のエラーとして呼び出し側へ流れる。
- `updateComment` / `deleteComment` で対象ドキュメントが存在しない場合、`update` は `not-found` で失敗し `false`、`delete` は成功扱い（Firestore の仕様）。

## 8. テスト観点（既存テストが確認していること / 未テストの観点）

既存（`comment_repository_test.dart`）:
- `addComment` が投稿のサブコレクションに保存すること／空でない `id` を指定するとその ID を使うこと。
- `getComments` が `createdAt` 昇順で返すこと／指定投稿に限定されること。
- `getCommentCount` が投稿ごとの件数を返すこと（0 件含む）。
- `updateComment` が本文を変え `updatedAt` を記録すること。
- `deleteComment` で削除されること。

既存（`test/rules/posts.test.mjs`）: 他人の投稿にコメントできる、コメント投稿者は `commentCount` を更新できない、他人のコメントは編集・削除できない。

未テスト:
- 書き込み失敗時に `false` を返すこと（例外の握りつぶし）。

## 9. 備考・既知の課題

- `getCommentCount` はコメント全件のスナップショットを購読して数えるため、コメント数が多い投稿ではフィードのカードごとに読み取りコストが増える（集計クエリ `count()` は使っていない）。
- `updatedAt` はクライアント時刻で、サーバータイムスタンプではない。
- 投稿削除時にサブコレクションは残る（基本設計 7 章）。
