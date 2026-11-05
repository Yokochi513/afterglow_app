# lib/ui/post/post_add_dialog.dart

| 項目 | 内容 |
|---|---|
| ファイル | `lib/ui/post/post_add_dialog.dart` |
| 基本設計 | [02 地図・投稿作成](../../02_地図・投稿作成.md) の「2.2 PostAddDialog」「3.2 投稿作成」「3.3 撮影場所の提案」 |
| 関連する基本設計 | [07 コンテスト](../../07_コンテスト.md)（4.1 応募） |
| レイヤ | View |
| 主な依存先 | `lib/ui/post/post_add_view_model.dart`, `lib/ui/post/photo_location_suggestion.dart`, `lib/data/models/contest.dart`, `package:flutter/material.dart`, `package:flutter/rendering.dart`（`RenderAbstractViewport`）, `package:image_picker`（`ImagePicker`, `XFile`）, `package:latlong2`（`LatLng`）, `package:provider`（`context.read`） |
| 主な利用元 | `lib/ui/map/map_screen.dart`（`_confirmSelectedLocation` から `showDialog` で表示） |
| テスト | `test/ui/post/post_add_dialog_test.dart` |

## 1. 責務

地図で選んだ位置に写真付き投稿を作成するダイアログ（PS_01 / PS_03 / Issue #40 / #46）。

- `PostAddViewModel` を生成・破棄し、その状態を描画する。
- UI 固有の処理だけを持つ: 画像選択（`ImagePicker`）、画像プレビューのページ送り（`PageController`）、キーボード表示時のプレビュー縮小とスクロール補正（Issue #38）、サムネイルのドラッグ並び替えの開始方法の切り替え、ViewModel の通知の SnackBar 表示、投稿成功時にダイアログを閉じる。
- 入力検証・送信・状態は持たない（[post_add_view_model.md](post_add_view_model.md)）。

## 2. 構成要素（クラス・関数・定数の一覧）

| 種別 | 名前 | 概要 |
|---|---|---|
| クラス | `PostAddDialog` | `StatefulWidget`。公開ウィジェット |
| クラス | `_PostAddDialogState` | `State` + `WidgetsBindingObserver` |
| 定数 | `_fieldsReservedHeight` | `280`（入力欄のために確保する高さ） |
| 定数 | `_previewMinHeight` | `96`（画像プレビューの最小高さ） |
| 定数 | `_focusScrollDelay` | `Duration(milliseconds: 350)`（フォーカス → スクロール補正の待ち） |
| 定数 | `_thumbnailSize` | `64`（サムネイルの一辺） |

主な private メソッド: `_showNotice`, `didChangeMetrics`, `_ensureFieldVisible`, `_scrollIntoViewOnFocus`, `_pickImages`, `_syncPage`, `_removeImage`, `_reorderImage`, `_showImageAt`, `_showPreviousImage`, `_showNextImage`, `_addTags`, `_submit`, `_buildPhotoLocationBanner`, `_thumbnailDragListener`, `_buildThumbnailStrip`, `_overlayButton`, `_buildContestSelector`, `_buildContestList`, `_buildDialog`。

## 3. 公開インターフェース（コンストラクタ引数・プロパティ・メソッドのシグネチャと説明）

```dart
const PostAddDialog({Key? key, required LatLng pos, List<XFile>? initialImages})
```

| 引数 | 説明 |
|---|---|
| `pos` | 地図でタップした投稿地点（ViewModel の `tappedLocation`） |
| `initialImages` | テストから選択済み画像を注入するための任意の初期値（`ImagePicker` を注入できないため） |

戻り値は無い（`showDialog<void>`）。投稿成功時のみ自ら `Navigator.pop()` する。閉じた後の選択状態のクリアは `MapScreen` 側が行う。

依存は `context.read()` で `PostRepository`・`ContestRepository`・`AuthRepository`・`ImageService` を受け取る（`DependencyScope` の提供が前提）。

## 4. 内部状態（フィールド・状態遷移）

| フィールド | 型 | 説明 |
|---|---|---|
| `_captionController` | `TextEditingController` | キャプション入力 |
| `_locationController` | `TextEditingController` | 場所名入力 |
| `_tagController` | `TextEditingController` | タグ入力（追加後にクリア） |
| `_imagePicker` | `ImagePicker` | 画像選択 |
| `_pageController` | `PageController` | プレビューの PageView |
| `_viewModel` | `late final PostAddViewModel` | `initState` で生成。getter `vm` で参照 |
| `_noticeSubscription` | `late final StreamSubscription<PostAddNotice>` | `vm.notices` の購読 |
| `_focusedFieldContext` | `BuildContext?` | フォーカス中の入力欄の context（スクロール補正用） |

画面の状態（画像・タグ・送信中など）はすべて ViewModel にあり、`ListenableBuilder` で再描画する。

### 4.1 ライフサイクル

| 契機 | 処理 |
|---|---|
| `initState` | `PostAddViewModel(tappedLocation: widget.pos, postRepository/contestRepository/authRepository/imageService: context.read())` を生成 → `notices.listen(_showNotice)` → `WidgetsBinding.instance.addObserver(this)` → `initialImages` があれば `vm.loadInitialImages`（await しない） |
| `dispose` | `removeObserver` → 通知購読 `cancel` → `_viewModel.dispose()` → 3 つの `TextEditingController` と `PageController` を `dispose` |

## 5. 処理詳細（メソッドごとの手順・分岐・呼び出す Repository/SDK）

### 5.1 ウィジェット構成

```
ListenableBuilder(listenable: _viewModel)
└─ Dialog(insetPadding: 横24・縦24)
   └─ ConstrainedBox(maxWidth 630, maxHeight 800)
      └─ Padding(LTRB 16,16,16,24)
         └─ LayoutBuilder  … previewMaxHeight = max(96, maxHeight - 280)
            └─ Stack
               ├─ AbsorbPointer(absorbing: vm.isPosting)
               │  └─ SingleChildScrollView
               │     └─ Column
               │        ├─ Text('投稿', titleLarge)
               │        ├─ 画像プレビュー（枠: grey400・幅2・角丸12、maxHeight=previewMaxHeight、AspectRatio 4:3）
               │        │   ├─ 0 枚: InkWell(onTap: _pickImages) … add_photo_alternate_outlined(40) +「タップして画像を選択」
               │        │   └─ 1 枚以上: Stack
               │        │       ├─ PageView.builder(_pageController, onPageChanged: vm.showImageAt) … Image.memory(cover, gaplessPlayback)
               │        │       ├─ 右上: × ボタン → _removeImage(vm.currentImageIndex)
               │        │       ├─ 2 枚以上: 左 chevron_left（先頭では無効）/ 右 chevron_right（末尾では無効）
               │        │       └─ 下: '{currentImageIndex+1} / {images.length}'
               │        ├─ 2 枚以上: _buildThumbnailStrip()
               │        ├─ _buildPhotoLocationBanner()
               │        ├─ Row: TextButton.icon('画像を追加'、上限到達で無効) … Spacer … '{images.length} / {maxImages}'
               │        ├─ TextField キャプション（minLines 3, maxLines null）※_scrollIntoViewOnFocus
               │        ├─ TextField 場所名 ※_scrollIntoViewOnFocus
               │        ├─ TextField タグ（例: #夜景 #桜）、helper「入力してEnterで追加」、onSubmitted: _addTags ※_scrollIntoViewOnFocus
               │        ├─ タグがあれば Wrap(Chip('#tag', onDeleted: vm.removeTag))
               │        ├─ _buildContestSelector()
               │        └─ ElevatedButton（幅いっぱい、vm.canSubmit で有効）… 送信中は白い CircularProgressIndicator(20px)、通常は「投稿する」
               └─ vm.isPosting のとき: 半透明黒(0x66000000)の全面オーバーレイ + 白カード（CircularProgressIndicator +「投稿中...」）
```

キーボードの inset は `Dialog` 内部の `AnimatedPadding` に任せ、ダイアログ側では二重にパディングしない。高さが足りないときはプレビューの `maxHeight` を `maxHeight - 280`（最小 96）に縮め、入力欄の余地を確保する。

### 5.2 撮影場所バナー `_buildPhotoLocationBanner`（Key: `photoLocationBanner`）

`vm.photoLocationResult` が `PhotoLocationSuggestion` でも `PhotoLocationAdopted` でもなければ `SizedBox.shrink()`。

| 状態 | 文言 |
|---|---|
| 採用中（`PhotoLocationAdopted`） | 撮影場所に投稿します |
| 再提案（`isReproposal == true`） | 撮影場所が変わりました（{photoNumber}枚目の写真） |
| 提案 | {photoNumber}枚目の写真の撮影場所が見つかりました（タップ地点から{formatDistance(distanceMeters)}） |

構成: `surfaceContainerLow` 背景・角丸 8 の Container に、`Icons.place`(16) + 文言（bodySmall）、その下の `Wrap` にボタン:

| ボタン（Key） | 表示条件 | 動作 |
|---|---|---|
| 撮影場所を使う（`usePhotoLocation`） | 提案中 | `vm.usePhotoLocation(suggestion.location)` |
| 無視（`ignorePhotoLocation`） | 提案中 | `vm.ignorePhotoLocation(suggestion.location)` |
| 元に戻す（`restoreTappedLocation`） | `vm.adoptedLocation != null`（再提案中も含む） | `vm.restoreTappedLocation()` |

絵文字は Web の同梱フォントで欠けるためアイコンで示す。

### 5.3 サムネイル一覧 `_buildThumbnailStrip`（画像 2 枚以上）

1. `thumbnailCacheSize = (64 * devicePixelRatio).round()` を計算（Issue #71 / `docs/adr/0001`: 原寸デコードによるメモリ枯渇対策）。
2. 高さ `64 + 8` の横向き `ReorderableListView.builder`（`buildDefaultDragHandles: false`, `onReorderItem: _reorderImage`）。
3. 各アイテム（Key: `ObjectKey(vm.images[index])`、右余白 8）:
   - `_thumbnailDragListener` でラップ → `GestureDetector(onTap: _showImageAt(index))`
   - 64×64、角丸 8 の枠。表示中は primary 色・幅 2、それ以外は grey400・幅 1
   - `Image.memory(previewBytes[index], cacheWidth/cacheHeight: thumbnailCacheSize, cover, gaplessPlayback)`
   - 左上に並び順番号 `index + 1`（黒 54% 背景・白 11pt）
4. 下に説明文「ドラッグ（タッチ操作は長押し）で並び替え。1枚目がサムネイルになります」（bodySmall・grey600）。

`_thumbnailDragListener`: `Theme.of(context).platform` が Android / iOS なら `ReorderableDelayedDragStartListener`（長押しで開始。横スクロールと競合しないため）、それ以外は `ReorderableDragStartListener`（即時）。Web でもテーマのプラットフォームに従う。

### 5.4 コンテスト選択 `_buildContestSelector` / `_buildContestList`

- `SwitchListTile('コンテストに応募する', value: vm.participateInContest, onChanged: 送信中は null / それ以外 vm.setParticipateInContest)`。
- ON のときだけ `StreamBuilder<List<Contest>>(stream: vm.entryOpenContests)`:
  | 状態 | 表示 |
  |---|---|
  | エラー | `vm.syncSelectedContest(null)` で選択解除 →「コンテスト一覧を取得できませんでした」 |
  | waiting | `LinearProgressIndicator` |
  | データあり | `selected = vm.syncSelectedContest(contests)`。0 件なら「募集中のコンテストがありません」 |
  | 1 件以上 | `DropdownButtonFormField<Contest>`（Key: `ValueKey(selected)`, `initialValue: selected`, ラベル「応募するコンテスト」, 項目は `contest.title`（省略表示）, `onChanged`: 送信中は null / それ以外 `vm.selectContest`）。選択中は下に「コンテスト終了後に投稿者名が公開されます」 |

`ValueKey(selected)` により、`syncSelectedContest` で選択が補正されたときにドロップダウンを作り直して表示を同期する。

### 5.5 イベントハンドラ

| メソッド | 処理 |
|---|---|
| `_pickImages` | `vm.checkCanPickImages()` が false なら終了 → `_imagePicker.pickMultiImage()`（等倍取得。圧縮は投稿時）→ `mounted` でなければ終了 → `vm.addImages(picked)` |
| `_syncPage` | 画像があり `_pageController.hasClients` なら `jumpToPage(vm.currentImageIndex)` |
| `_removeImage(i)` | `vm.removeImage(i)` → `_syncPage()` |
| `_reorderImage(o, n)` | `vm.reorderImage(o, n)` → `_syncPage()` |
| `_showImageAt(i)` | `vm.showImageAt(i)` → `_syncPage()` |
| `_showPreviousImage` / `_showNextImage` | 端でなければ `previousPage` / `nextPage`（200ms, easeInOut）。表示位置の更新は `onPageChanged: vm.showImageAt` 経由 |
| `_addTags(raw)` | `vm.addTagsFromInput(raw)` → `_tagController.clear()` |
| `_submit` | `Navigator.of(context)` を先に取得 → `vm.submit(caption: _captionController.text, locationName: _locationController.text)` → true かつ `mounted` なら `navigator.pop()` |
| `_showNotice(notice)` | `mounted` なら `ScaffoldMessenger.of(context).showSnackBar(SnackBar(Text(message), backgroundColor: isError ? Colors.red : null))` |

### 5.6 キーボード表示時のスクロール補正（Issue #38）

モバイルブラウザではキーボード表示に伴う自動スクロールが効かず、フォーカスした欄が隠れることがあるため、自前で補正する。

1. `_scrollIntoViewOnFocus(child)`: `Builder` で入力欄の context を得て `Focus(skipTraversal: true, includeSemantics: false)` で包む。
   - フォーカス取得: `_focusedFieldContext = fieldContext`、`350ms` 後に（`mounted` かつ `fieldContext.mounted` なら）`_ensureFieldVisible`。
   - フォーカス喪失: 保持中の context と同一なら `_focusedFieldContext = null`。
2. `didChangeMetrics`（ビューポート変化）: フォーカス中の欄があれば `200ms` 後に `_ensureFieldVisible`（`Dialog` の `AnimatedPadding` による縮小が終わるのを待つ）。
3. `_ensureFieldVisible(fieldContext)`:
   1. `RenderBox` で attached、かつ `Scrollable.maybeOf` があること。`RenderAbstractViewport.maybeOf` が取れること。満たさなければ何もしない。
   2. `revealTop = getOffsetToReveal(ro, 0.0).offset`、`revealBottom = getOffsetToReveal(ro, 1.0).offset`。現在の `pixels` が `revealBottom ≦ pixels ≦ revealTop` なら全体が見えているので何もしない。
   3. それ以外は `Scrollable.ensureVisible(fieldContext, alignment: 0.3, duration: 150ms, curve: easeOut)`。

## 6. データ仕様（読み書きする Firestore/Storage のパス・フィールド、定数値）

Firestore / Storage への直接アクセスはない（ViewModel → `PostRepository` 経由）。

| 定数 | 値 |
|---|---|
| ダイアログ最大サイズ | 幅 630 / 高さ 800 |
| `insetPadding` | 横 24・縦 24 |
| 内側 Padding | 左 16・上 16・右 16・下 24 |
| `_fieldsReservedHeight` | 280 |
| `_previewMinHeight` | 96 |
| プレビュー縦横比 | 4:3 |
| `_thumbnailSize` | 64 |
| `_focusScrollDelay` | 350ms |
| `didChangeMetrics` の待ち | 200ms |
| `ensureVisible` | alignment 0.3・150ms・easeOut |
| ページ送り | 200ms・easeInOut |

## 7. 例外・エラー処理（例外の扱い・戻り値・表示メッセージ）

- エラー・案内はすべて ViewModel の `notices` を SnackBar で表示する（文言は [post_add_view_model.md](post_add_view_model.md) 7 章）。`isError` なら赤背景。
- ダイアログ固有の表示文言: 「コンテスト一覧を取得できませんでした」「募集中のコンテストがありません」（いずれも本文中のテキスト）。
- 送信中は `AbsorbPointer` で全入力を無効化し、オーバーレイ「投稿中...」を表示する。スイッチ・ドロップダウンの `onChanged` も null にする。
- `pickMultiImage` 等の例外は捕捉しない。

## 8. テスト観点（既存テストが確認していること / 未テストの観点）

`test/ui/post/post_add_dialog_test.dart`（`withDependencies` + `AppDependencies` にモックを注入。GPS は `_GpsImageService`、送信は `_RecordingPostRepository` で記録）:

- コンテスト応募: 既定はトグル OFF で通常投稿、ON 後に選択して応募・OFF で選択解除、応募対象が一覧から消えても通常投稿へ切り替わらない、送信中に応募先が削除されても応募先 ID を保持
- 撮影場所（Issue #46）: 遠い GPS の提案・採用・元に戻す・無視、50m 以内や GPS なしではバナー非表示、採用位置／元に戻した後のタップ地点が `createPost` に渡る、並べ替えは再提案のみで採用写真の削除時だけ位置を戻す
- キーボード: パディングが二重に入らない、下部に空白が生じない、閉じると元に戻る、プレビューが縮む／非表示時は 4:3 のまま、画面外の入力欄へフォーカスするとスクロールして表示、`AnimatedPadding` が Dialog の 1 つだけ
- 並び替え（Issue #40）: 2 枚以上でサムネイル一覧表示・1 枚では非表示、並び替えでプレビュー順序が同期、長押しドラッグで並び替え、並び替え後の削除

未テストの観点:

- `ImagePicker` を使う画像選択経路（注入不可のため `initialImages` で代替）
- 投稿成功時にダイアログが閉じること、送信中オーバーレイの表示
- 通知の SnackBar 表示色（`isError`）
- マウス端末での即時ドラッグ開始

## 9. 備考・既知の課題

- `initialImages` の読み込みは `initState` から await せずに開始する。
- 投稿成功時は `isPosting` が true のままダイアログを閉じる（オーバーレイが閉じる直前まで残る）。
- 説明欄のラベルは「キャプション」（基本設計 2.2 の表では「説明」と表記）。
