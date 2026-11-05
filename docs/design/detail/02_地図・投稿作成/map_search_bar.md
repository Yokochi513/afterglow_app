# lib/ui/map/widgets/map_search_bar.dart

| 項目 | 内容 |
|---|---|
| ファイル | `lib/ui/map/widgets/map_search_bar.dart` |
| 基本設計 | [02 地図・投稿作成](../../02_地図・投稿作成.md) の 2.1 MapScreen（検索バー）/ 3.5 場所検索 |
| 関連する基本設計 | なし |
| レイヤ | View（部品） |
| 主な依存先 | `data/services/geocoding_service.dart`（`GeocodingService`, `PlaceSearchResult`）。パッケージ: `provider` |
| 主な利用元 | `lib/ui/map/map_screen.dart` |
| テスト | `test/ui/map/map_search_bar_test.dart` |

## 1. 責務

地図画面上部に重ねる場所検索バー（Issue #39）。入力した地名・施設名を `GeocodingService.search` で検索し、直下のパネルに候補・該当なし・エラーを出し分ける。候補を選ぶと `onPlaceSelected` で親へ通知する（地図の移動は親が行う）。

Nominatim の利用ポリシーに合わせ、検索は入力確定（キーボードの検索アクション・検索ボタン）時だけ行い、1 文字ごとのオートコンプリートはしない。

## 2. 構成要素

| 名前 | 種別 | 公開 | 概要 |
|---|---|---|---|
| `MapSearchBar` | `StatefulWidget` | 公開 | 検索バー |
| `_MapSearchBarState` | `State<MapSearchBar>` | 非公開 | 入力・検索状態と描画 |

## 3. 公開インターフェース

| シグネチャ | 説明 |
|---|---|
| `const MapSearchBar({super.key, required ValueChanged<PlaceSearchResult> onPlaceSelected})` | `onPlaceSelected` は候補選択時に呼ばれる |

`GeocodingService` は引数で受けず、`context.read<GeocodingService>()` で取得する。

## 4. 内部状態

| フィールド | 型 | 初期値 | 説明 |
|---|---|---|---|
| `_geocodingService` | `GeocodingService`（`late final`） | `context.read<GeocodingService>()` | 検索の実行 |
| `_controller` | `TextEditingController` | 新規生成 | 入力欄。`dispose` で破棄 |
| `_places` | `List<PlaceSearchResult>?` | `null` | null = 未検索（パネルを出さない）、空リスト = 該当なし |
| `_hasError` | `bool` | `false` | 検索失敗（通信断・API エラー等） |
| `_isSearching` | `bool` | `false` | 検索中。検索アイコンをスピナーに替え、再検索を抑止 |

表示状態:

| 状態 | `_isSearching` | `_hasError` | `_places` | パネル |
|---|---|---|---|---|
| 未検索 | false | false | null | 出さない |
| 検索中 | true | false | null | 出さない（検索アイコンがスピナー） |
| 候補あり | false | false | 1 件以上 | 候補一覧 |
| 該当なし | false | false | `[]` | 「該当する場所が見つかりませんでした。」 |
| 失敗 | false | true | null | 「検索に失敗しました。時間をおいて再度お試しください。」 |

## 5. 処理詳細

### 5.1 ライフサイクル

- `initState`: オーバーライドしない（`_geocodingService` は初回参照時に `context.read`）。
- `dispose`: `_controller.dispose()` の後 `super.dispose()`。

### 5.2 `_search()`（`Future<void>`）

`TextField.onSubmitted` と検索ボタンから呼ぶ。

1. `query = _controller.text.trim()`。空、または `_isSearching` 中なら何もしない。
2. `setState`: `_isSearching = true`, `_hasError = false`, `_places = null`（前回のパネルを消す）。
3. `response = await _geocodingService.search(query)`。
4. `mounted` でなければ終了。
5. `setState`: `_isSearching = false`, `_hasError = !response.isSuccess`, `_places = response.isSuccess ? response.places : null`。

### 5.3 `_selectPlace(PlaceSearchResult place)`

1. `setState(() => _places = null)`（パネルを閉じる。入力文字列は残す）。
2. `FocusScope.of(context).unfocus()`（キーボードを閉じる）。
3. `widget.onPlaceSelected(place)`。

### 5.4 `_clear()`

`_controller.clear()` の後、`setState` で `_places = null`, `_hasError = false`。`_isSearching` は戻さない。

### 5.5 `build`

```
Column(mainAxisSize: min)
├ Material(elevation: 4, borderRadius: 28)
│ └ TextField(controller, textInputAction: search, onSubmitted: (_) => _search())
│     decoration: hintText '場所を検索', OutlineInputBorder(radius 28, borderSide none),
│                 filled, fillColor colorScheme.surface,
│                 prefixIcon: _isSearching ? 24x24 CircularProgressIndicator(strokeWidth 2)（padding 12）
│                                          : IconButton(Icons.search, tooltip '検索', onPressed: _search),
│                 suffixIcon: IconButton(Icons.close, tooltip 'クリア', onPressed: _clear)
└ （_hasError || _places != null のとき）
  Padding(top: 8) > Material(elevation: 4, borderRadius: 12, clipBehavior: antiAlias) > _buildResultPanel(places)
```

### 5.6 `_buildResultPanel(List<PlaceSearchResult>? places)`

1. `_hasError` → `ListTile(leading: Icon(Icons.error_outline), title: Text('検索に失敗しました。時間をおいて再度お試しください。'))`
2. `places == null || places.isEmpty` → `ListTile(leading: Icon(Icons.search_off), title: Text('該当する場所が見つかりませんでした。'))`
3. それ以外 → `Column(mainAxisSize: min)` に候補ごとの `ListTile(leading: Icon(Icons.place_outlined), title: Text(place.displayName, maxLines: 2, overflow: ellipsis), onTap: () => _selectPlace(place))`

候補は最大 5 件（`GeocodingService` の `limit`）のため、スクロールは設けていない。

## 6. データ仕様

なし（HTTP の詳細は [geocoding_service.md](geocoding_service.md)）。

## 7. 例外・エラー処理

| 状況 | 扱い |
|---|---|
| 検索失敗（`isSuccess == false`） | パネルにエラー文言を表示。`GeocodingService` が例外を投げないため try/catch は持たない |
| 空入力・空白のみ | 検索しない（パネルも出さない） |
| 検索中の再送信 | `_isSearching` で無視 |
| 検索完了前の破棄 | `mounted` を確認して `setState` しない |

## 8. テスト観点

既存テスト（`map_search_bar_test.dart`、`MockClient` を注入した `GeocodingService` を `withDependencies` で提供）:

- 検索を確定すると候補が表示され、選択で `onPlaceSelected` が呼ばれる。
- 該当なしのときは「該当する場所が見つかりませんでした。」を表示する。
- 検索失敗時はエラーメッセージを表示する。
- クリアボタンで入力と候補が消える。
- 空の入力では検索されず、パネルも出ない。

未テストの観点:

- 検索中にスピナーが出て、再送信が無視されること。
- 候補選択後にパネルが閉じ、フォーカスが外れること。

## 9. 備考・既知の課題

- 検索中に「クリア」すると入力とパネルは消えるが、進行中の検索は取り消されず、完了時に結果パネルが再表示される。
- Nominatim の「1 秒 1 回まで」は `_isSearching` による同時実行抑止のみで、連続した確定操作の間隔は制御していない。
- 候補選択後も入力欄に検索語が残る（再検索・修正しやすくするため。消すにはクリア）。
