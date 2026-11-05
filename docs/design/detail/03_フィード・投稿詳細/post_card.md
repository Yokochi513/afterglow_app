# lib/ui/core/widgets/post_card.dart

| 項目 | 内容 |
|---|---|
| ファイル | `lib/ui/core/widgets/post_card.dart` |
| 基本設計 | [03 フィード・投稿詳細](../../03_フィード・投稿詳細.md) の 2.1「FeedPage / PostCard」 |
| 関連する基本設計 | [07 コンテスト](../../07_コンテスト.md)（コンテスト詳細の応募作品一覧）、[04 コメント・リアクション](../../04_コメント・リアクション.md)（カード上のいいね・コメント数） |
| レイヤ | View（機能横断の部品） |
| 主な依存先 | `data/models/post.dart`（`Post`）、`data/repositories/user_repository.dart`（`UserRepository`）、`data/repositories/comment_repository.dart`（`CommentRepository`）、`ui/core/widgets/contest_entry_badge.dart`（`ContestEntryBadge`）、`ui/core/widgets/reaction_bar.dart`（`ReactionBar`）、`cached_network_image`、`provider` |
| 主な利用元 | `lib/ui/feed/feed_page.dart`（フィード一覧）、`lib/ui/contest/contest_detail_page.dart`（`_EntryTile` の応募作品カード） |
| テスト | `test/ui/core/post_card_test.dart`、`test/ui/feed/feed_page_test.dart`（一覧内での表示） |

> 地図のピンから開くサマリーダイアログは本ウィジェットではなく `PostCardView`（[post_widget.md](post_widget.md)）である。名前が似ているので注意。

## 1. 責務

- 1 投稿を一覧用の横長カードで表示する: 左に先頭画像のサムネイル、右に投稿者名・コンテストバッジ・説明（最大 2 行）・タグ・いいね/コメント数。
- いいねはカード上でトグルできる（`ReactionBar(compact: true)`）。
- コメント数は `posts/{postId}/comments` の件数を購読して実数を出す（`posts.commentCount` は更新されないため）。
- カードのタップは `onTap` に委譲する（遷移先は呼び出し元が決める）。

## 2. 構成要素（クラス・関数・定数の一覧）

| 名前 | 種別 | 概要 |
|---|---|---|
| `PostCard` | `StatefulWidget`（公開） | 投稿カード |
| `_PostCardState` | `State<PostCard>` | 購読 Stream の保持と描画 |
| `_PostCardState._thumbnailSize` | `static const double` = `96` | サムネイルの一辺（px） |
| `_buildThumbnail` / `_buildThumbnailPlaceholder` / `_buildAuthorName` / `_buildContestBadge` / `_buildTags` / `_buildCounts` | private メソッド | 各部品の組み立て |

## 3. 公開インターフェース

```dart
class PostCard extends StatefulWidget {
  const PostCard(this.post, {super.key, this.onTap});
  final Post post;
  final VoidCallback? onTap;
}
```

| 引数 | 型 | 説明 |
|---|---|---|
| `post` | `Post`（位置引数・必須） | 表示する投稿 |
| `onTap` | `VoidCallback?` | カード（`InkWell`）タップ時に呼ばれる。null ならタップ無効 |

## 4. 内部状態（フィールド・状態遷移）

| フィールド | 型 | 説明 |
|---|---|---|
| `_userRepository` | `late final UserRepository` | `context.read<UserRepository>()` |
| `_commentRepository` | `late final CommentRepository` | `context.read<CommentRepository>()` |
| `_commentCount` | `late final Stream<int>` | `_commentRepository.getCommentCount(widget.post.id)`。build ごとに作り直すと再購読になるため State に保持する |

状態遷移はない（表示のみ）。

## 5. 処理詳細

### 5.1 `build()`

```
Card(margin: symmetric(h12, v6), clipBehavior: antiAlias)
└ InkWell(onTap: widget.onTap)
  └ Padding(all 12)
    └ Row(crossAxisAlignment: start)
      ├ _buildThumbnail(post)
      ├ SizedBox(width 12)
      └ Expanded
        └ Column(crossAxisAlignment: start)
          ├ _buildAuthorName(post)
          ├ [post.contestId != null] SizedBox(4) + _buildContestBadge(post)
          ├ SizedBox(4)
          ├ [post.caption.isNotEmpty] Text(caption, maxLines 2, ellipsis, bodyMedium)
          ├ [post.tags.isNotEmpty] SizedBox(6) + _buildTags(post)
          ├ SizedBox(8)
          └ _buildCounts(post)
```

### 5.2 `_buildThumbnail(Post post)`

1. `imageUrl = post.imageUrls.isEmpty ? null : post.imageUrls.first`。
2. `ClipRRect(radius 8)` + `SizedBox(96×96)` の中に:
   - `imageUrl == null`: `_buildThumbnailPlaceholder(Icon(Icons.image_not_supported))`。
   - それ以外: `CachedNetworkImage(imageUrl, fit: BoxFit.cover)`。読込中は 20×20 の `CircularProgressIndicator(strokeWidth: 2)`、失敗時は `Icon(Icons.broken_image_outlined)` をプレースホルダで包む。

`_buildThumbnailPlaceholder(child)` は `ColoredBox(colorScheme.surfaceContainerHighest)` の中央に `child` を置く。

### 5.3 `_buildAuthorName(Post post)`

| 条件 | 表示 |
|---|---|
| `post.userId.isEmpty`（匿名期間中のコンテスト投稿） | `'匿名'`（購読しない） |
| それ以外 | `StreamBuilder(stream: _userRepository.watchUser(post.userId))`。`snapshot.data?.username ?? ''` が空なら `'名無しさん'`、そうでなければユーザー名 |

文字は `titleSmall` を太字、1 行・省略記号。購読前（`snapshot.data == null`）とユーザー未登録・ユーザー名空はいずれも `'名無しさん'` になる。

### 5.4 `_buildContestBadge(Post post)`

`ContestEntryBadge(contestId: post.contestId!, voteCount: post.voteCount)`（[contest_entry_badge.md](../07_コンテスト/contest_entry_badge.md)）。`contestId != null` のときだけ呼ばれる。

### 5.5 `_buildTags(Post post)`

`Wrap(spacing: 6, runSpacing: -8)` に `Chip(label: Text('#$tag'), labelStyle: labelSmall, visualDensity: compact, materialTapTargetSize: shrinkWrap)` を並べる。

### 5.6 `_buildCounts(Post post)`

`Row` に以下を並べる（文字スタイルは `labelMedium`）。

1. `ReactionBar(post: post, compact: true)`（いいねのトグル。[reaction_bar.md](../04_コメント・リアクション/reaction_bar.md)）
2. `SizedBox(16)` + `Icon(Icons.mode_comment_outlined, size: 16)` + `SizedBox(4)`
3. `StreamBuilder<int>(stream: _commentCount, initialData: post.commentCount)` → `Text('${snapshot.data ?? post.commentCount}')`。購読開始前は非正規化値を出してちらつきを防ぐ。

## 6. データ仕様

| 読み取り先 | 経由 | 用途 |
|---|---|---|
| `users/{post.userId}`（`username`） | `UserRepository.watchUser` | 投稿者名 |
| `posts/{post.id}/comments`（件数） | `CommentRepository.getCommentCount` | コメント数 |
| `Post` の `imageUrls`・`caption`・`tags`・`contestId`・`voteCount`・`commentCount`・`userId` | 引数 | 表示 |

書き込みは本ウィジェット自身では行わない（いいねは `ReactionBar` が行う）。

## 7. 例外・エラー処理

- サムネイル取得失敗は `errorWidget` で `Icons.broken_image_outlined` を表示する。
- ユーザー購読・コメント数購読のエラーは個別処理していない。`StreamBuilder` の `snapshot.data` が null になり、それぞれ `'名無しさん'`・`post.commentCount` にフォールバックする。

## 8. テスト観点

既存テスト（`test/ui/core/post_card_test.dart`）:

- 説明・タグ・件数を表示する。
- `commentCount` が古くても実際のコメント数を表示する（Issue #58 / #59）。
- 投稿者が見つからないときは「名無しさん」を表示する。
- 画像の無い投稿はプレースホルダアイコンを表示する。
- タップで `onTap` を呼ぶ。

未テストの観点:

- `userId` が空（匿名）のとき「匿名」を表示すること。
- コンテスト投稿で `ContestEntryBadge` を表示すること。
- 説明が空のとき説明行を出さないこと。

## 9. 備考・既知の課題

- 基本設計 2.1 は「投稿者名は取得前は空欄」としているが、実装は取得前も `'名無しさん'` を表示する（UID を出さない点は一致）。
- `_buildAuthorName` は build のたびに `watchUser` の新しい Stream を `StreamBuilder` に渡すため、再ビルドごとに再購読になる（コメント数の Stream は State に保持して回避済み）。
- `_commentCount` は `late final` で最初の `widget.post.id` に固定される。キーを付けずに並び順が変わるリストで再利用されると、別投稿のコメント数を出し続ける可能性がある。`FeedPage` は `ValueKey(post.id)` を付けて回避しているが、`ContestDetailPage` の `_EntryTile` はキーを付けていない。
- カードごとにコメントを全件購読するため、コメントが多いと読取コストが増える（基本設計 7 章）。
