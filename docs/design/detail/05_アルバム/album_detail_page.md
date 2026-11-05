# lib/ui/album/album_detail_page.dart

| 項目 | 内容 |
|---|---|
| ファイル | `lib/ui/album/album_detail_page.dart` |
| 基本設計 | [05 アルバム](../../05_アルバム.md) の「2. 画面・コンポーネント構成」（AlbumDetailPage・所有者向け操作・投稿選択ダイアログ）「3. 処理フロー」（詳細・投稿追加/削除・アルバム削除） |
| 関連する基本設計 | [03 フィード・投稿詳細](../../03_フィード・投稿詳細.md)（グリッドから `PostDetailPage` へ遷移）、[04 コメント・リアクション](../../04_コメント・リアクション.md)（`ReactionBar` / `CommentSection` を差し込む） |
| レイヤ | View |
| 主な依存先 | `lib/data/models/{album,app_user,post}.dart`, `lib/data/repositories/{album,auth,post,user}_repository.dart`, `lib/ui/post/post_detail_page.dart`, `lib/ui/album/widgets/album_edit_dialog.dart`, `lib/ui/core/widgets/{comment_section,reaction_bar}.dart`, `package:provider`, `package:cached_network_image` |
| 主な利用元 | `lib/ui/album/album_list_page.dart`（`_AlbumTile` のタップ） |
| テスト | なし |

## 1. 責務

1 つのアルバムを購読し、作成者名・説明・投稿数と、含まれる投稿の 3 列サムネイルグリッドを表示する。サムネイルのタップで投稿詳細へ遷移する。所有者にだけ、AppBar の編集・削除、FAB の投稿追加（投稿選択ダイアログ）、グリッドの長押しによる取り外しを提供する。

## 2. 構成要素（クラス・関数・定数の一覧）

| 名前 | 種別 | 概要 |
|---|---|---|
| `AlbumDetailPage` | `StatelessWidget`（公開） | 画面本体。アルバムを購読して Scaffold を組み立てる |
| `AlbumDetailPage._confirmDeleteAlbum` | private メソッド | 削除確認 → 削除 → 一覧へ戻る |
| `_AlbumBody` | `StatelessWidget` | ヘッダー情報と投稿グリッド |
| `_AlbumPostTile` | `StatelessWidget` | グリッドの 1 枚。タップで詳細、所有者は長押しで取り外し |
| `_AlbumPostTile._confirmRemovePost` | private メソッド | 取り外し確認 → `removePost` |
| `_AlbumPostPickerDialog` | `StatelessWidget` | 所有者の投稿をチェックボックスで選び、即時に追加／削除するダイアログ |

## 3. 公開インターフェース（コンストラクタ引数・プロパティ・メソッドのシグネチャと説明）

```dart
const AlbumDetailPage({Key? key, required String albumId})
```

| プロパティ | 型 | 説明 |
|---|---|---|
| `albumId` | `String` | 表示するアルバムの ID |

依存（`context.read`）: `AlbumRepository`, `AuthRepository`, `UserRepository`, `PostRepository`。

private ウィジェットの引数:

| ウィジェット | 引数 |
|---|---|
| `_AlbumBody` | `album: Album`, `isOwner: bool` |
| `_AlbumPostTile` | `post: Post`, `album: Album`, `isOwner: bool` |
| `_AlbumPostPickerDialog` | `album: Album` |

## 4. 内部状態（フィールド・状態遷移）

すべて `StatelessWidget` で、ローカル状態は持たない。表示状態は次の購読・Future で決まる。

| 対象 | 取得方法 | 再取得の契機 |
|---|---|---|
| アルバム | `watchAlbum(albumId)`（Stream） | ドキュメント変更のたび |
| 作成者 | `watchUser(album.ownerId)`（Stream） | ユーザー変更のたび |
| 投稿一覧 | `getPostsByIds(album.postIds)`（Future） | `FutureBuilder` の `key: ValueKey(album.postIds.join(','))` が変わったとき（および `_AlbumBody` の再構築時） |
| ピッカーのチェック状態 | `watchAlbum(album.id)`（Stream, `initialData: album`） | ダイアログ内で再購読 |
| ピッカーの候補 | `getUserPosts(album.ownerId)`（Stream） | 投稿変更のたび |

`isOwner = albumRepository.isOwnedBy(album, currentUid)`。`currentUid` は `build` 時点の `AuthRepository.currentUserId`。

## 5. 処理詳細（メソッドごとの手順・分岐・呼び出す Repository/SDK）

### `AlbumDetailPage.build`

```
StreamBuilder<Album?>(stream: watchAlbum(albumId))
├─ waiting → Scaffold(body: Center(CircularProgressIndicator))
├─ null    → Scaffold(appBar: AppBar(), body: Center(Text('アルバムが見つかりませんでした')))
└─ album   → Scaffold
     ├─ appBar: AppBar(title: Text(album.title), actions: isOwner なら
     │     ├─ IconButton(Icons.edit, tooltip 'アルバムを編集')
     │     │     → showDialog<bool>(builder: (_) => AlbumEditDialog(album: album))
     │     └─ IconButton(Icons.delete_outline, tooltip 'アルバムを削除')
     │           → _confirmDeleteAlbum(context, albumRepository, album))
     ├─ floatingActionButton: isOwner なら
     │     FloatingActionButton(Icons.add_photo_alternate_outlined, tooltip '投稿を追加')
     │       → showDialog<void>(builder: (_) => _AlbumPostPickerDialog(album: album))
     │   それ以外 null
     └─ body: _AlbumBody(album, isOwner)
```

### `_confirmDeleteAlbum(context, albumRepository, album)`

1. `navigator` と `messenger` を `await` 前に退避する。
2. `showDialog<bool>`: タイトル `'アルバムを削除'`、本文 `'このアルバムを削除しますか？\n含まれる投稿自体は削除されません。'`、アクション `'キャンセル'`（false）・`'削除'`（true）。
3. `true` 以外なら終了。
4. `albumRepository.deleteAlbum(album.id)` が `true` なら `navigator.pop()` で一覧へ戻る。
5. `false` なら SnackBar `'アルバムの削除に失敗しました'`（背景赤）。

### `_AlbumBody.build`

```
SingleChildScrollView
└─ Column(stretch)
   ├─ Padding(16) / Column(start)
   │   ├─ StreamBuilder<AppUser?>(watchUser(ownerId))
   │   │     → Text('作成者: <名前 or 名無しさん>', bodySmall)
   │   ├─ description が空でなければ SizedBox(12) + Text(description)
   │   ├─ SizedBox(12)
   │   └─ Text('<postIds.length>件の投稿', bodySmall)
   ├─ Divider(height: 1)
   ├─ FutureBuilder<List<Post>>(key: ValueKey(postIds.join(',')),
   │                            future: getPostsByIds(album.postIds))
   │   ├─ waiting → Padding(32) + スピナー
   │   ├─ 空      → Padding(32) + Text(isOwner ? 'まだ投稿がありません。＋から追加できます' : 'まだ投稿がありません')
   │   └─ GridView.builder(shrinkWrap, NeverScrollableScrollPhysics, padding 8,
   │        crossAxisCount 3, mainAxisSpacing 4, crossAxisSpacing 4) → _AlbumPostTile
   └─ SizedBox(height: 24)
```

- `getPostsByIds` は ID ごとに個別 `get` し、存在しない（削除済み）投稿を除外する。並びは `postIds` の順。

### `_AlbumPostTile.build`

1. `thumbnailUrl = post.imageUrls.isNotEmpty ? post.imageUrls.first : null`。
2. `GestureDetector`:
   - `onTap`: `Navigator.push(MaterialPageRoute(builder: (_) => PostDetailPage(post, reactionBar: ReactionBar(post: post), commentSection: CommentSection(post: post))))`。
   - `onLongPress`: `isOwner` のとき `_confirmRemovePost(context)`、それ以外は `null`。
3. 子: サムネイルが無ければ grey.shade200 + `Icon(Icons.image_not_supported_outlined, grey)`。あれば `CachedNetworkImage(fit: cover)`、placeholder は grey.shade200、errorWidget は grey.shade200 + `Icon(Icons.broken_image_outlined, grey)`。

### `_confirmRemovePost(context)`

1. `messenger` と `albumRepository` を退避する。
2. `showDialog<bool>`: タイトル `'アルバムから削除'`、本文 `'この投稿をアルバムから取り除きますか？\n投稿自体は削除されません。'`、アクション `'キャンセル'`（false）・`'取り除く'`（true）。
3. `true` 以外なら終了。
4. `albumRepository.removePost(album.id, post.id)` が `false` のときだけ SnackBar `'アルバムからの削除に失敗しました'`（背景赤）。成功時は `watchAlbum` の更新でグリッドが再構築される。

### `_AlbumPostPickerDialog.build`

```
AlertDialog(title: '投稿を追加')
├─ content: SizedBox(320×400)
│   └─ StreamBuilder<Album?>(watchAlbum(album.id), initialData: album)
│        postIds = data?.postIds ?? album.postIds
│        └─ StreamBuilder<List<Post>>(getUserPosts(album.ownerId))
│             ├─ waiting → スピナー
│             ├─ 空      → Text('追加できる投稿がありません')
│             └─ ListView.builder → CheckboxListTile
│                   value: postIds.contains(post.id)
│                   onChanged: true → addPost(album.id, post.id)
│                              false → removePost(album.id, post.id)
│                   secondary: 48×48 サムネイル（無し・読込中・失敗は grey.shade200）
│                   title: caption（空なら '(説明なし)'、2 行・省略）
└─ actions: TextButton('閉じる') → pop()
```

- ダイアログは詳細画面とは別ルートで親の再構築を受けないため、チェック状態を即時反映できるよう `watchAlbum` をダイアログ内で再購読する。
- 候補は `album.ownerId` の投稿（＝所有者本人の投稿）に限られる。

## 6. データ仕様（読み書きする Firestore/Storage のパス・フィールド、定数値）

| 操作 | Repository メソッド | 対象 |
|---|---|---|
| アルバム購読 | `AlbumRepository.watchAlbum` | `albums/{albumId}` |
| 作成者購読 | `UserRepository.watchUser` | `users/{ownerId}.username` |
| 投稿取得 | `PostRepository.getPostsByIds` | `posts/{postId}`（ID ごとに個別取得） |
| 候補購読 | `PostRepository.getUserPosts(ownerId)` | `posts`（`userId == ownerId`、クライアント側で新しい順） |
| 投稿追加 / 取り外し | `AlbumRepository.addPost` / `removePost` | `albums/{albumId}.postIds` |
| アルバム削除 | `AlbumRepository.deleteAlbum` | `albums/{albumId}` |
| 編集 | `AlbumEditDialog` 経由で `updateAlbum` | `title`, `description` |

グリッドは 3 列・間隔 4・外側パディング 8。ピッカーは 320×400。

## 7. 例外・エラー処理（例外の扱い・戻り値・表示メッセージ）

| 状況 | 挙動 |
|---|---|
| アルバムが存在しない・削除された | 「アルバムが見つかりませんでした」 |
| アルバム削除失敗 | SnackBar「アルバムの削除に失敗しました」（赤） |
| 取り外し失敗 | SnackBar「アルバムからの削除に失敗しました」（赤） |
| ピッカーでの追加・削除失敗 | 戻り値を無視し通知なし（チェック状態は購読値のまま戻る） |
| 投稿取得失敗・全投稿削除済み | 「まだ投稿がありません」（所有者は「まだ投稿がありません。＋から追加できます」） |
| 作成者が取得できない | 「作成者: 名無しさん」 |
| 画像読込失敗 | `broken_image_outlined` |

## 8. テスト観点（既存テストが確認していること / 未テストの観点）

既存: 画面のテストはない。`watchAlbum` / `addPost` / `removePost` / `deleteAlbum` / `isOwnedBy` は `album_repository_test.dart` で確認済み。

未テスト:
- 所有者／非所有者で AppBar アクション・FAB・長押しが出し分けられること。
- 削除成功で一覧に戻ること、失敗時の SnackBar。
- 削除済み投稿がグリッドから除外されること。
- ピッカーのチェックで即時に追加／削除されること。

## 9. 備考・既知の課題

- アルバム削除時、`watchAlbum` が先に `null` を流すと `navigator.pop()` の前に一瞬「アルバムが見つかりませんでした」が表示され得る。
- `FutureBuilder` の `future` を `build` 内で生成しているため、`postIds` が変わらなくても `_AlbumBody` が再構築される（タイトル・説明の編集など）と投稿を取り直し、一時的にスピナーに戻る。
- 件数表示（`postIds.length`）は削除済み投稿を含み、グリッドの枚数と一致しないことがある。
- ピッカーの追加・削除失敗はユーザーに通知されない（基本設計 6 章「失敗時のみ SnackBar」と差異）。
- 管理者はルール上編集できるが、`isOwnedBy` が所有者のみを見るため UI に操作は出ない。
