# lib/ui/album/album_list_page.dart

| 項目 | 内容 |
|---|---|
| ファイル | `lib/ui/album/album_list_page.dart` |
| 基本設計 | [05 アルバム](../../05_アルバム.md) の「2. 画面・コンポーネント構成」（AlbumListPage）「3. 処理フロー」（一覧・作成） |
| 関連する基本設計 | [00 システム概要](../../00_システム概要.md)（下部タブ「Album」） |
| レイヤ | View |
| 主な依存先 | `lib/data/models/{album,app_user}.dart`, `lib/data/repositories/{album,user}_repository.dart`, `lib/ui/album/album_detail_page.dart`, `lib/ui/album/widgets/album_edit_dialog.dart`, `package:provider`, `package:cached_network_image` |
| 主な利用元 | `lib/app/main_shell.dart`（タブ index 2「Album」） |
| テスト | なし |

## 1. 責務

承認済みユーザー全員のアルバムを新しい順に一覧表示し、各行から詳細画面へ遷移させる。FAB からアルバム作成ダイアログを開く。表示範囲は「全体」で、作成は誰でも行える。

## 2. 構成要素（クラス・関数・定数の一覧）

| 名前 | 種別 | 概要 |
|---|---|---|
| `AlbumListPage` | `StatelessWidget`（公開） | 一覧画面 |
| `_AlbumTile` | `StatelessWidget`（private） | 一覧の 1 行（カバー・タイトル・所有者名・投稿数） |

## 3. 公開インターフェース（コンストラクタ引数・プロパティ・メソッドのシグネチャと説明）

```dart
const AlbumListPage({Key? key})
```

引数なし。依存（`context.read`）: `AlbumRepository`（ページ）、`UserRepository`（`_AlbumTile`）。

## 4. 内部状態（フィールド・状態遷移）

状態を持たない（`StatelessWidget`）。表示は `getAlbums()` の購読結果のみに依存する。

`_AlbumTile` のフィールド: `album: Album`（final）。

## 5. 処理詳細（メソッドごとの手順・分岐・呼び出す Repository/SDK）

### `AlbumListPage.build`

```
Scaffold
├─ appBar: AppBar(title: 'アルバム')
├─ floatingActionButton: FloatingActionButton(Icons.add, tooltip: 'アルバムを作成')
│     onPressed → showDialog<bool>(builder: (_) => const AlbumEditDialog())
└─ body: StreamBuilder<List<Album>>(stream: albumRepository.getAlbums())
      ├─ waiting → Center(CircularProgressIndicator)
      ├─ 空      → Center(Text('まだアルバムがありません'))
      └─ 1 件以上 → ListView.separated(padding: vertical 8,
                     separator: Divider(height: 1), item: _AlbumTile)
```

- `snapshot.data` が null（エラー含む）は空リスト扱い。
- 作成ダイアログの戻り値（`bool`）は使わない。作成結果は `getAlbums()` の購読で一覧に反映される。

### `_AlbumTile.build`

`ListTile` を返す。

| スロット | 内容 |
|---|---|
| `leading` | 56×56 の `SizedBox`。`coverImageUrl` が null／空なら `Container(grey.shade200)` + `Icon(Icons.photo_album_outlined, grey)`。あれば `CachedNetworkImage(fit: cover)`、placeholder は grey.shade200 の `Container`、errorWidget は grey.shade200 + `Icon(Icons.broken_image_outlined, grey)` |
| `title` | `Text(album.title, maxLines: 1, ellipsis)` |
| `subtitle` | `StreamBuilder<AppUser?>(stream: userRepository.watchUser(album.ownerId))` → `'<所有者名>・<postIds.length>件'`。所有者名が空・未取得なら `'名無しさん'`。1 行・省略表示 |
| `onTap` | `Navigator.push(MaterialPageRoute(builder: (_) => AlbumDetailPage(albumId: album.id)))` |

## 6. データ仕様（読み書きする Firestore/Storage のパス・フィールド、定数値）

| 操作 | Repository メソッド | 対象 |
|---|---|---|
| 一覧購読 | `AlbumRepository.getAlbums()` | `albums`（`createdAt` 降順） |
| 所有者名購読 | `UserRepository.watchUser(album.ownerId)` | `users/{uid}.username` |

投稿数は `album.postIds.length`（削除済み投稿の ID も含む）。

## 7. 例外・エラー処理（例外の扱い・戻り値・表示メッセージ）

| 状況 | 表示 |
|---|---|
| 読み込み中 | 中央スピナー |
| 0 件・購読エラー | 「まだアルバムがありません」（エラーと 0 件を区別しない） |
| 所有者が取得できない | 「名無しさん」 |
| カバー画像の読込失敗 | `broken_image_outlined` アイコン |

## 8. テスト観点（既存テストが確認していること / 未テストの観点）

既存: なし（並び順は `album_repository_test.dart` の `getAlbums` で確認）。

未テスト:
- 0 件時の文言、行のサブタイトル（所有者名・件数・「名無しさん」フォールバック）。
- 行タップで `AlbumDetailPage` へ遷移すること、FAB で `AlbumEditDialog` が開くこと。

## 9. 備考・既知の課題

- カバー画像を設定する UI がないため、実運用では常にプレースホルダー表示（基本設計 7 章）。
- 件数は `postIds` の長さで、削除済み投稿を含む。
- 行ごとに `users/{ownerId}` を個別購読するため、アルバム数に比例して購読数が増える。
