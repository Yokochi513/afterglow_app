# lib/ui/post/widgets/post_widget.dart

| 項目 | 内容 |
|---|---|
| ファイル | `lib/ui/post/widgets/post_widget.dart` |
| 基本設計 | [03 フィード・投稿詳細](../../03_フィード・投稿詳細.md) の 2.2「表示モード（PostDetailView）」の summary 列 |
| 関連する基本設計 | [02 地図・投稿作成](../../02_地図・投稿作成.md)（地図ピンのタップで開く） |
| レイヤ | View |
| 主な依存先 | `data/models/post.dart`（`Post`）、`ui/post/widgets/post_detail_view.dart`（`PostDetailView` / `PostViewMode`） |
| 主な利用元 | `lib/ui/map/map_screen.dart`（`_openSummary` の `showDialog`） |
| テスト | `test/ui/post/post_widget_test.dart` |

## 1. 責務

- 地図のマーカータップで開く投稿サマリーの Dialog（クラス名 `PostCardView`）。
- 中身は `PostDetailView(mode: PostViewMode.summary)` で、写真・投稿者・説明・タグ・いいね・コメントだけを見せる。場所名・地図ミニプレビュー・編集/削除は出さない（地図上で開くため冗長、編集導線は詳細ページへ一本化）。
- 「詳細を見る」ボタンで、呼び出し元が渡した `onOpenDetail` を呼ぶ（`MapScreen` はダイアログを閉じて `PostDetailPage` を push する）。

## 2. 構成要素（クラス・関数・定数の一覧）

| 名前 | 種別 | 概要 |
|---|---|---|
| `PostCardView` | `StatelessWidget`（公開） | サマリー Dialog |

ファイル名（`post_widget.dart`）とクラス名（`PostCardView`）が一致しない。フィードの一覧カード `PostCard`（[post_card.md](post_card.md)）とは別物。

## 3. 公開インターフェース

```dart
const PostCardView(
  this.post, {
  super.key,
  this.reactionBar,
  this.commentSection,
  this.onOpenDetail,
});
```

| 引数 | 型 | 説明 |
|---|---|---|
| `post` | `Post`（位置引数・必須） | 表示する投稿 |
| `reactionBar` | `Widget?` | リアクションバー（#13）の差し込み口。null なら出さない |
| `commentSection` | `Widget?` | コメントセクション（#12）の差し込み口。null なら出さない |
| `onOpenDetail` | `VoidCallback?` | 「詳細を見る」押下時に呼ばれる。null なら導線を出さない |

## 4. 内部状態

なし（`StatelessWidget`）。編集/削除の権限判定などの状態は内部の `PostDetailView` が ViewModel を生成して持つ（summary では編集/削除ボタンは出ない）。

## 5. 処理詳細

### 5.1 `build()`

```
Dialog(insetPadding: symmetric(h24, v24))
└ AnimatedPadding(duration 200ms, padding: bottom = MediaQuery.viewInsets.bottom)
  └ ConstrainedBox(maxWidth: 630, maxHeight: 800)
    └ Padding(fromLTRB(16, 16, 16, 24))
      └ Column(mainAxisSize: min)
        ├ Flexible
        │ └ PostDetailView(post, mode: PostViewMode.summary,
        │                  reactionBar: reactionBar, commentSection: commentSection)
        └ [onOpenDetail != null]
          SizedBox(8) + Align(centerRight)
            └ TextButton.icon(Icons.open_in_new (18), '詳細を見る', onPressed: onOpenDetail)
```

- `AnimatedPadding` でソフトキーボード（コメント入力時）の高さ分だけ下を空け、入力欄が隠れないようにする。
- `Expanded` ではなく `Flexible` にして、内容が短いときに Dialog が `maxHeight` 800 まで伸びないようにする。`PostDetailView` は高さが有界であることを前提にする（内部の `SingleChildScrollView` でスクロール）。

### 5.2 呼び出し元（`MapScreen._openSummary`）

```dart
showDialog<void>(
  context: context,
  builder: (dialogContext) => PostCardView(
    post,
    reactionBar: ReactionBar(post: post),
    commentSection: CommentSection(post: post),
    onOpenDetail: () {
      Navigator.of(dialogContext).pop();
      _openDetail(post); // PostDetailPage を push
    },
  ),
);
```

## 6. データ仕様

本ファイル自身は Firestore/Storage にアクセスしない。定数: Dialog の `insetPadding` 24、最大 630×800、内側余白 左右上 16 / 下 24、`AnimatedPadding` 200ms。

## 7. 例外・エラー処理

なし（中身は [post_detail_view.md](post_detail_view.md) を参照）。

## 8. テスト観点

既存テスト（`test/ui/post/post_widget_test.dart`）:

- Dialog の中に `PostDetailView` を表示する。
- サマリーはいいねとコメントを出す。
- サマリーは地図ミニプレビューを出さない。
- サマリーは自投稿でも編集・削除を出さない。
- `onOpenDetail` を渡すと「詳細を見る」を出し、押すと呼ばれる。未指定なら出さない。

未テストの観点: キーボード表示時の `AnimatedPadding`、最大サイズ制約。

## 9. 備考・既知の課題

- ファイル名とクラス名の不一致（`post_widget.dart` / `PostCardView`）、および `PostCard` との名前の近さが紛らわしい。
