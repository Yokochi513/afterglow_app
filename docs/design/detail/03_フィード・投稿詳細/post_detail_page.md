# lib/ui/post/post_detail_page.dart

| 項目 | 内容 |
|---|---|
| ファイル | `lib/ui/post/post_detail_page.dart` |
| 基本設計 | [03 フィード・投稿詳細](../../03_フィード・投稿詳細.md) の 2.2「表示モード（PostDetailView）」の full 列 |
| 関連する基本設計 | [02 地図・投稿作成](../../02_地図・投稿作成.md)（サマリーの「詳細を見る」）、[05 アルバム](../../05_アルバム.md)、[07 コンテスト](../../07_コンテスト.md)、[08 通知](../../08_通知.md)、[09 プロフィール](../../09_プロフィール.md)（いずれも遷移元） |
| レイヤ | View |
| 主な依存先 | `data/models/post.dart`（`Post`）、`ui/post/widgets/post_detail_view.dart`（`PostDetailView`） |
| 主な利用元 | `lib/ui/feed/feed_page.dart`、`lib/ui/map/map_screen.dart`（`_openDetail`）、`lib/ui/profile/profile_page.dart`、`lib/ui/album/album_detail_page.dart`、`lib/ui/contest/contest_detail_page.dart`、`lib/ui/notification/notification_page.dart` |
| テスト | `test/ui/post/post_detail_page_test.dart` |

## 1. 責務

- 投稿詳細をフルページで表示する外枠。`Scaffold` + `AppBar`、最大幅・余白だけを与え、中身は `PostDetailView`（既定の `PostViewMode.full`）に任せる。
- 場所名・地図ミニプレビュー・編集/削除・ワイド画面の 2 カラム切替などの振る舞いはすべて `PostDetailView` 側にある（[post_detail_view.md](post_detail_view.md)）。

## 2. 構成要素（クラス・関数・定数の一覧）

| 名前 | 種別 | 概要 |
|---|---|---|
| `PostDetailPage` | `StatelessWidget`（公開） | 詳細ページ |
| `PostDetailPage._maxContentWidth` | `static const double` = `1400` | 超ワイド画面で内容が横に伸びすぎないための上限幅 |

## 3. 公開インターフェース

```dart
const PostDetailPage(
  this.post, {
  super.key,
  this.reactionBar,
  this.commentSection,
});
```

| 引数 | 型 | 説明 |
|---|---|---|
| `post` | `Post`（位置引数・必須） | 表示する投稿 |
| `reactionBar` | `Widget?` | リアクションバー（#13）の差し込み口。null なら表示しない。呼び出し元は通常 `ReactionBar(post: post)` を渡す |
| `commentSection` | `Widget?` | コメントセクション（#12）の差し込み口。null なら表示しない。通常 `CommentSection(post: post)` を渡す |

## 4. 内部状態

なし（`StatelessWidget`）。

## 5. 処理詳細

### 5.1 `build()`

```
Scaffold
├ appBar: AppBar(title: Text('投稿'))
└ body: SafeArea
  └ Center
    └ ConstrainedBox(maxWidth: 1400)
      └ Padding(fromLTRB(24, 16, 24, 24))
        └ PostDetailView(post, reactionBar: reactionBar, commentSection: commentSection)
```

- `mode` は渡さないため `PostViewMode.full` になる。
- 高さは `Scaffold` の body で有界になるため、`PostDetailView` の内部 `Stack` / `SingleChildScrollView` が成立する。
- 幅の上限 1400px の内側で、`PostDetailView` が `maxWidth >= 900` のとき 2 カラムに切り替える。

### 5.2 遷移元と渡し方

| 遷移元 | `reactionBar` / `commentSection` |
|---|---|
| `FeedPage._openDetail` | 両方渡す |
| `MapScreen._openDetail`（サマリーの「詳細を見る」でダイアログを閉じてから push） | 両方渡す |
| `ProfilePage`・`AlbumDetailPage`・`ContestDetailPage._EntryTile` | 両方渡す |
| `NotificationPage`（通知タップで投稿を取得して push） | どちらも渡さない |

いずれも `MaterialPageRoute` で push する。削除成功時は `PostDetailView` が `Navigator.pop()` で本ページを閉じる。

## 6. データ仕様

本ファイル自身は Firestore/Storage を読み書きしない。定数: `_maxContentWidth = 1400`、余白 左右 24 / 上 16 / 下 24。

## 7. 例外・エラー処理

なし（中身の例外処理は [post_detail_view.md](post_detail_view.md) を参照）。

## 8. テスト観点

既存テスト（`test/ui/post/post_detail_page_test.dart`）は本ページを通して `PostDetailView` の振る舞いを網羅している。本ファイル固有の観点は以下。

- `Scaffold` のフルページとして描画される。
- ワイド画面（1400×1000）で 2 カラム、狭い画面（400×900）で 1 カラムになる。
- `reactionBar` / `commentSection` の差し込み口に渡したウィジェットが描画される。

未テストの観点: `maxWidth: 1400` による幅の上限。

## 9. 備考・既知の課題

- `NotificationPage` からの遷移はリアクションバー・コメントセクションを渡していないため、通知から開いた詳細ではいいね・コメントが表示されない。基本設計 2.2 の「full: いいね・コメント ○」と食い違う。
