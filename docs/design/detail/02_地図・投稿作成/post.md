# lib/data/models/post.dart

| 項目 | 内容 |
|---|---|
| ファイル | `lib/data/models/post.dart` |
| 基本設計 | [02 地図・投稿作成](../../02_地図・投稿作成.md) の「4. データ設計」 |
| 関連する基本設計 | [00 システム概要](../../00_システム概要.md)（5. データモデル）/ [03 フィード・投稿詳細](../../03_フィード・投稿詳細.md) / [05 アルバム](../../05_アルバム.md) / [07 コンテスト](../../07_コンテスト.md) / [09 プロフィール](../../09_プロフィール.md) |
| レイヤ | Model |
| 主な依存先 | `package:cloud_firestore`（`Timestamp`） |
| 主な利用元 | `lib/data/repositories/post_repository.dart`, `lib/data/repositories/contest_repository.dart`, `lib/ui/post/post_add_view_model.dart`, `lib/ui/map/map_screen.dart`, `lib/ui/feed/feed_page.dart`, `lib/ui/core/widgets/post_card.dart`, `lib/ui/core/widgets/reaction_bar.dart`, `lib/ui/core/widgets/comment_section.dart`, `lib/ui/post/post_detail_page.dart`, `lib/ui/post/post_detail_view_model.dart`, `lib/ui/post/widgets/post_detail_view.dart`, `lib/ui/post/widgets/post_widget.dart`, `lib/ui/album/album_detail_page.dart`, `lib/ui/contest/contest_detail_page.dart`, `lib/ui/profile/profile_page.dart` |
| テスト | `test/data/models/post_test.dart` |

## 1. 責務

Firestore `posts/{postId}` ドキュメント 1 件を表すイミュータブルなデータクラス。Firestore の生 `Map` から欠損フィールドを既定値で補いながら `Post` を組み立てる（`fromSnapshot`）。

書き込み用の `toMap()` は持たない。書き込むフィールドの組み立ては `PostRepository.createPost` / `updatePost` が個別に行う（[post_repository.md](post_repository.md)）。

## 2. 構成要素（クラス・関数・定数の一覧）

| 種別 | 名前 | 概要 |
|---|---|---|
| クラス | `Post` | 投稿データ。`const` コンストラクタ + `factory Post.fromSnapshot` |

定数・トップレベル関数はなし。

## 3. 公開インターフェース（コンストラクタ引数・プロパティ・メソッドのシグネチャと説明）

### 3.1 コンストラクタ

```dart
const Post({
  required this.id,
  required this.userId,
  required this.caption,
  required this.imageUrls,
  required this.latitude,
  required this.longitude,
  required this.createdAt,
  this.locationName,
  this.tags = const [],
  this.likeCount = 0,
  this.commentCount = 0,
  this.contestId,
  this.stayAnonymous = false,
  this.voteCount = 0,
  this.updatedAt,
})
```

### 3.2 プロパティ

| プロパティ | 型 | 必須 | 既定値 | 説明 |
|---|---|---|---|---|
| `id` | `String` | ○ | — | ドキュメント ID（作成時はクライアントで `millisecondsSinceEpoch` 文字列を採番） |
| `userId` | `String` | ○ | — | 投稿者 UID。コンテスト応募作品の匿名期間中は `''` |
| `caption` | `String` | ○ | — | 説明文 |
| `imageUrls` | `List<String>` | ○ | — | Storage のダウンロード URL。並び順が表示順で、先頭がサムネイル |
| `latitude` | `double` | ○ | — | 投稿位置の緯度 |
| `longitude` | `double` | ○ | — | 投稿位置の経度 |
| `createdAt` | `DateTime` | ○ | — | 投稿日時 |
| `locationName` | `String?` | — | `null` | 場所名（自由入力）。未設定なら null |
| `tags` | `List<String>` | — | `const []` | タグ一覧（`#` なし、PS_03） |
| `likeCount` | `int` | — | `0` | いいね数（非正規化） |
| `commentCount` | `int` | — | `0` | コメント数（非正規化）。フィードのカードがサブコレクションを数えずに済むよう保持 |
| `contestId` | `String?` | — | `null` | コンテスト応募作品の場合のみ設定。通常投稿は null |
| `stayAnonymous` | `bool` | — | `false` | コンテスト終了後も匿名のままにするか（現行の作成処理では常に false で書く） |
| `voteCount` | `int` | — | `0` | コンテスト投票数。通常投稿では 0 |
| `updatedAt` | `DateTime?` | — | `null` | 編集日時（PS_08）。未編集なら null |

### 3.3 ファクトリ

```dart
factory Post.fromSnapshot(String id, Map<String, dynamic> document)
```

ドキュメント ID と `DocumentSnapshot.data()` の Map から `Post` を生成する。

## 4. 内部状態（フィールド・状態遷移）

全フィールド `final`。状態遷移なし。

## 5. 処理詳細（メソッドごとの手順・分岐・呼び出す Repository/SDK）

### 5.1 `Post.fromSnapshot`

各フィールドを次の規則で変換する。

| フィールド | 変換 | 欠損時 |
|---|---|---|
| `id` | 引数 `id` をそのまま | — |
| `userId` | `document['userId']` | `''` |
| `caption` | `document['caption']` | `''` |
| `imageUrls` | `List<String>.from(document['imageUrls'] ?? [])`（新しいリストへコピー） | `[]` |
| `latitude` | `document['latitude']?.toDouble()`（int で保存されていても double 化） | `0.0` |
| `longitude` | `document['longitude']?.toDouble()` | `0.0` |
| `createdAt` | `(document['createdAt'] as Timestamp?)?.toDate()` | `DateTime.now()` |
| `locationName` | `document['locationName']` | `null` |
| `tags` | `List<String>.from(document['tags'] ?? [])`（コピー） | `[]` |
| `likeCount` | `document['likeCount']` | `0` |
| `commentCount` | `document['commentCount']` | `0` |
| `contestId` | `document['contestId']` | `null` |
| `stayAnonymous` | `document['stayAnonymous']` | `false` |
| `voteCount` | `document['voteCount']` | `0` |
| `updatedAt` | `(document['updatedAt'] as Timestamp?)?.toDate()` | `null` |

`imageUrls` と `tags` は `List.from` で新しい（変更可能な）リストにコピーするため、元の Map のリストとは独立する。

## 6. データ仕様（読み書きする Firestore/Storage のパス・フィールド、定数値）

読み取り元は `posts/{postId}`。フィールドは 3.2 の表のとおり（Firestore 上の型: 日時は `Timestamp`、座標は number、`imageUrls`・`tags` は string 配列）。

コンテスト応募作品の実投稿者は本クラスに含まれず、`posts/{postId}/private/author.userId` にある（`PostRepository.getAuthorId` で取得）。

## 7. 例外・エラー処理（例外の扱い・戻り値・表示メッセージ）

- 欠損フィールドはすべて既定値へフォールバックし、例外は投げない。
- 型が想定と異なる場合（例: `createdAt` が `Timestamp` でない、`likeCount` が `int` でない）は `as` キャスト・代入で `TypeError` が発生する。特別な捕捉はしない。

## 8. テスト観点（既存テストが確認していること / 未テストの観点）

`test/data/models/post_test.dart` が確認していること:

- 全フィールドが揃ったドキュメントの変換
- 拡張フィールド（locationName / tags / likeCount / commentCount / updatedAt）の変換
- コンテスト用フィールド（contestId / stayAnonymous / voteCount）の変換
- 拡張フィールド欠損時の既定値（後方互換）
- `userId`・`caption` 欠損時の `''`、`imageUrls` 欠損時の空リスト
- 整数座標の double 化、座標欠損時の 0.0
- `createdAt` 欠損時におおむね現在時刻になること
- `tags`・`imageUrls` が元のリストとは別の変更可能なリストにコピーされること

未テストの観点:

- 型不一致（例: `likeCount` が double）のときの挙動

## 9. 備考・既知の課題

- `createdAt` 欠損時の `DateTime.now()` は読むたびに値が変わるため、並び替え結果が不安定になりうる（通常の作成経路では必ず書かれる）。
- 座標欠損時は (0, 0)（ギニア湾）にピンが立つ。
- `==` / `hashCode` / `copyWith` は未実装。比較・更新は ID や再生成で行う。
