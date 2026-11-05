# lib/data/models/comment.dart

| 項目 | 内容 |
|---|---|
| ファイル | `lib/data/models/comment.dart` |
| 基本設計 | [04 コメント・リアクション](../../04_コメント・リアクション.md) の「4. データ設計」 |
| 関連する基本設計 | [08 通知](../../08_通知.md)（`onCommentCreated` がコメントの `userId` を通知の actor に使う） |
| レイヤ | Model |
| 主な依存先 | `package:cloud_firestore`（`Timestamp`） |
| 主な利用元 | `lib/data/repositories/comment_repository.dart`, `lib/ui/core/widgets/comment_section.dart` |
| テスト | 専用のモデルテストはなし。`test/data/repositories/comment_repository_test.dart` が `toMap` / `fromSnapshot` を経由して間接的に確認 |

## 1. 責務

投稿に付くテキストのみのコメント 1 件を表すイミュータブルなデータクラス。Firestore の `posts/{postId}/comments/{commentId}` ドキュメントとの相互変換（`fromSnapshot` / `toMap`）を担う。

## 2. 構成要素（クラス・関数・定数の一覧）

| 名前 | 種別 | 概要 |
|---|---|---|
| `Comment` | クラス | コメント 1 件のモデル |
| `Comment.fromSnapshot` | factory コンストラクタ | Firestore のマップからの生成 |
| `Comment.toMap` | メソッド | Firestore へ書き込むマップへの変換 |

定数はなし。

## 3. 公開インターフェース（コンストラクタ引数・プロパティ・メソッドのシグネチャと説明）

### コンストラクタ

```dart
const Comment({
  required String id,
  required String postId,
  required String userId,
  required String text,
  required DateTime createdAt,
  DateTime? updatedAt,
})
```

### プロパティ

| プロパティ | 型 | 説明 |
|---|---|---|
| `id` | `String` | ドキュメント ID。新規作成時は `''` を渡し、Repository に採番させる |
| `postId` | `String` | 親投稿の ID |
| `userId` | `String` | コメント投稿者の UID |
| `text` | `String` | 本文（テキストのみ） |
| `createdAt` | `DateTime` | 作成日時 |
| `updatedAt` | `DateTime?` | 編集日時。未編集なら `null` |

### メソッド

| シグネチャ | 説明 |
|---|---|
| `factory Comment.fromSnapshot(String id, Map<String, dynamic> document)` | ドキュメント ID とデータマップから生成する |
| `Map<String, dynamic> toMap()` | `id` を除くフィールドを Firestore 書き込み用マップに変換する |

## 4. 内部状態（フィールド・状態遷移）

すべて `final` で、状態遷移はない。`copyWith` は持たない（編集は Repository の `updateComment` がフィールド単位で更新する）。

## 5. 処理詳細（メソッドごとの手順・分岐・呼び出す Repository/SDK）

### `Comment.fromSnapshot`

1. `id` は引数をそのまま使う。
2. `postId` / `userId` / `text` は `document['x'] ?? ''` で欠損時に空文字へフォールバックする。
3. `createdAt` は `(document['createdAt'] as Timestamp?)?.toDate()`。欠損（`null`）時は `DateTime.now()` を使う。
4. `updatedAt` は `(document['updatedAt'] as Timestamp?)?.toDate()`。欠損時は `null` のまま。

### `toMap`

1. `postId` / `userId` / `text` をそのまま格納する。
2. `createdAt` を `Timestamp.fromDate(createdAt)` に変換する。
3. `updatedAt` が非 null のときだけ `'updatedAt': Timestamp.fromDate(updatedAt!)` を含める（collection-if）。null なら**キー自体を含めない**。
4. `id` は含めない（ドキュメント ID として扱う）。

## 6. データ仕様（読み書きする Firestore/Storage のパス・フィールド、定数値）

パス: `posts/{postId}/comments/{commentId}`（パスの組み立ては `CommentRepository` が行う）

| フィールド | Firestore 型 | Dart 型 | 欠損時の既定値 |
|---|---|---|---|
| `postId` | string | `String` | `''` |
| `userId` | string | `String` | `''` |
| `text` | string | `String` | `''` |
| `createdAt` | Timestamp | `DateTime` | `DateTime.now()` |
| `updatedAt` | Timestamp（任意） | `DateTime?` | `null`（`toMap` では null 時にキーを出力しない） |

## 7. 例外・エラー処理（例外の扱い・戻り値・表示メッセージ）

- `createdAt` / `updatedAt` が `Timestamp` 以外の型だった場合、`as Timestamp?` のキャストで `TypeError` が発生する（捕捉しない）。
- `postId` 等が文字列以外の型の場合も、代入時に型エラーとなる。
- それ以外の欠損は既定値で吸収する。

## 8. テスト観点（既存テストが確認していること / 未テストの観点）

既存（`comment_repository_test.dart` 経由）:
- `addComment` で保存したフィールド（`postId` / `userId` / `text` / `createdAt`）が読み戻せること。
- `updateComment` 後に `updatedAt` が非 null になること。

未テスト:
- フィールド欠損時のフォールバック（`fromSnapshot` に空マップを渡すケース）。
- `updatedAt == null` のとき `toMap` に `updatedAt` キーが含まれないこと。

## 9. 備考・既知の課題

- `createdAt` 欠損時の `DateTime.now()` フォールバックは読み取りのたびに値が変わるため、`createdAt` が欠けたドキュメントは並び順・表示日時が不安定になる（通常の書き込み経路では必ず設定される）。
- `postId` は親パスからも分かるが、ドキュメント内にも冗長に保持している。
