# lib/data/services/image_service.dart

| 項目 | 内容 |
|---|---|
| ファイル | `lib/data/services/image_service.dart` |
| 基本設計 | [02 地図・投稿作成](../../02_地図・投稿作成.md) の「3.2 投稿作成」「3.3 撮影場所の提案」「6. 入力チェック・エラー処理」 |
| 関連する基本設計 | [00 システム概要](../../00_システム概要.md)（8. 非機能） |
| レイヤ | Service |
| 主な依存先 | `package:exif_reader`（`readExifFromBytes`, `IfdRatios`）, `package:flutter_image_compress`（`FlutterImageCompress`, `CompressFormat`）, `package:image_picker`（`XFile`）, `package:latlong2`（`LatLng`） |
| 主な利用元 | `lib/app/dependencies.dart`（生成・`Provider<ImageService>` で提供）, `lib/data/repositories/post_repository.dart`（`compressImage`）, `lib/ui/post/post_add_view_model.dart`（`isAllowedExtension` / `validateSizes` / `extractGpsLocation`） |
| テスト | `test/data/services/image_service_test.dart`（他に `post_repository_test.dart`・`post_add_view_model_test.dart`・`post_add_dialog_test.dart` がサブクラスで差し替え） |

## 1. 責務

投稿画像に関する端末側の処理をまとめた薄いラッパー（NFR_02 / §8.1）。

- 拡張子の許可判定
- バイト数（1 枚・合計）の上限検証
- アップロード前の圧縮（短辺 2048px・品質 85%・JPEG）
- 元画像の EXIF から撮影位置（GPS）を読み取る（Issue #46）

Firebase には触れない。テストで重い処理（圧縮・EXIF 読取）を差し替えられるよう、メソッドは override 可能な通常のインスタンスメソッドとしている。

## 2. 構成要素（クラス・関数・定数の一覧）

| 種別 | 名前 | 値 / 概要 |
|---|---|---|
| クラス | `ImageService` | 本体 |
| 定数 | `allowedExtensions` | `{'jpg', 'jpeg', 'png', 'bmp', 'heic'}` |
| 定数 | `maxImageBytes` | `10 * 1024 * 1024`（10MB） |
| 定数 | `maxTotalBytes` | `100 * 1024 * 1024`（100MB） |
| 定数 | `maxShorterSidePixels` | `2048` |
| 定数 | `compressQuality` | `85` |
| メソッド | `extractGpsLocation` | EXIF → `LatLng?` |
| メソッド | `isAllowedExtension` | ファイル名 → bool |
| メソッド | `validateSizes` | バイト列一覧 → エラーメッセージ or null |
| メソッド | `compressImage` | `XFile` → 圧縮済み `Uint8List` |

## 3. 公開インターフェース（コンストラクタ引数・プロパティ・メソッドのシグネチャと説明）

```dart
ImageService();

Future<LatLng?> extractGpsLocation(Uint8List bytes);
bool isAllowedExtension(String fileName);
String? validateSizes(List<Uint8List> imageBytes);
Future<Uint8List> compressImage(XFile image);
```

| メソッド | 戻り値 | 説明 |
|---|---|---|
| `extractGpsLocation(bytes)` | `LatLng?` | 撮影位置。読めない・不正なら null（例外を投げない） |
| `isAllowedExtension(fileName)` | `bool` | 末尾の拡張子（大文字小文字無視）が `allowedExtensions` に含まれるか |
| `validateSizes(imageBytes)` | `String?` | 上限超過ならエラーメッセージ、問題なければ null |
| `compressImage(image)` | `Uint8List` | 圧縮後の JPEG バイト列 |

## 4. 内部状態（フィールド・状態遷移）

なし（ステートレス）。

## 5. 処理詳細（メソッドごとの手順・分岐・呼び出す Repository/SDK）

### 5.1 `extractGpsLocation`

1. 全体を `try` で囲む。`readExifFromBytes(bytes)` で EXIF を読む。
2. ローカル関数 `coordinate(name, positive, negative)` で緯度・経度を個別に求める。
   1. `data.tags['GPS GPS$name']?.values` と `data.tags['GPS GPS${name}Ref']?.printable` を取る（`name` は `Latitude` / `Longitude`）。
   2. 次のいずれかなら `null`:
      - 値が `IfdRatios` でない
      - 要素数が 3（度・分・秒）でない
      - 分母が 0 の要素がある
      - Ref が `positive`（`N`/`E`）でも `negative`（`S`/`W`）でもない
   3. 各要素を `toDouble()`。非有限・負の値がある、または分 ≧ 60、秒 ≧ 60 なら `null`。
   4. `度 + 分/60 + 秒/3600` を計算し、Ref が `negative` なら符号を反転して返す。
3. `latitude = coordinate('Latitude', 'N', 'S')`、`longitude = coordinate('Longitude', 'E', 'W')`。
4. どちらかが null、`|lat| > 90`、`|lng| > 180`、または `(0, 0)` なら `null`。
5. `LatLng(latitude, longitude)` を返す。
6. 例外はすべて捕捉して `null`。

### 5.2 `isAllowedExtension`

1. `fileName.lastIndexOf('.')` を探す。`.` が無い、または末尾が `.` なら `false`。
2. `.` 以降を小文字化し、`allowedExtensions` に含まれるかを返す。

### 5.3 `validateSizes`

1. 各バイト列を順に見て、`length > maxImageBytes` のものがあれば即座に `'1枚あたり10MBを超える画像は投稿できません'` を返す。
2. 合計が `maxTotalBytes` を超えたら `'画像の合計サイズが100MBを超えています'` を返す。
3. いずれも満たさなければ `null`。

境界値はちょうど 10MB / 100MB を許容する（`>` 判定）。

### 5.4 `compressImage`

1. `image.readAsBytes()` で元画像を読む。
2. `FlutterImageCompress.compressWithList(bytes, minWidth: 2048, minHeight: 2048, quality: 85, format: CompressFormat.jpeg)` を呼ぶ。縦横比を保って短辺が 2048px になるよう縮小する。短辺が 2048px 以下の画像は拡大しない（等倍）。
3. 結果を返す。

## 6. データ仕様（読み書きする Firestore/Storage のパス・フィールド、定数値）

Firestore / Storage への読み書きはない。定数値は 2 章のとおり。

参照する EXIF タグ: `GPS GPSLatitude`, `GPS GPSLatitudeRef`, `GPS GPSLongitude`, `GPS GPSLongitudeRef`。

## 7. 例外・エラー処理（例外の扱い・戻り値・表示メッセージ）

| メソッド | 扱い |
|---|---|
| `extractGpsLocation` | 全例外を捕捉して `null` |
| `isAllowedExtension` | 例外なし |
| `validateSizes` | 例外なし。メッセージ文字列を返し、`PostAddViewModel` が SnackBar 用の通知に流す |
| `compressImage` | 捕捉しない（`readAsBytes`・圧縮の失敗は呼び出し元 `PostRepository.createPost` の `catch` で投稿失敗になる） |

## 8. テスト観点（既存テストが確認していること / 未テストの観点）

`test/data/services/image_service_test.dart`:

- EXIF の GPS から東京駅の座標を読む（`test/fixtures` の画像）
- GPS の無い写真は null
- 壊れたバイト列でも例外を投げず null
- 許可拡張子（大文字を含む）を受け入れる
- 非対応拡張子・拡張子なしを拒否する
- サイズが上限内なら null、1 枚 10MB 超・合計 100MB 超でそれぞれのメッセージ

未テストの観点:

- `compressImage`（プラグイン依存のためユニットテストでは他テストがサブクラスで素通しに差し替えている）
- 南緯・西経（符号反転）、分・秒 ≧ 60、(0, 0) の除外
- 境界値（ちょうど 10MB / 100MB）

## 9. 備考・既知の課題

- 拡張子判定はファイル名だけで行い、中身（マジックナンバー）は確認しない。
- HEIC は拡張子としては許可するが、`Image.memory` でのプレビューや圧縮の可否はプラットフォーム（特に Web）のデコーダに依存する。
- サイズ検証は圧縮前の元画像のバイト数で行う。アップロードされるのは圧縮後の JPEG。
- `ignore: unnecessary_import` で `image_picker` を直接 import している（`flutter_image_compress` も `XFile` を再エクスポートするが、依存を明示するため）。
