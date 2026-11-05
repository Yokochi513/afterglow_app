# lib/data/models/album.dart

| 項目 | 内容 |
|---|---|
| ファイル | `lib/data/models/album.dart` |
| 基本設計 | [05 アルバム](../../05_アルバム.md) の「4. データ設計」 |
| 関連する基本設計 | なし |
| レイヤ | Model |
| 主な依存先 | `package:cloud_firestore`（`Timestamp`） |
| 主な利用元 | `lib/data/repositories/album_repository.dart`, `lib/ui/album/album_list_page.dart`, `lib/ui/album/album_detail_page.dart`, `lib/ui/album/widgets/album_edit_dialog.dart` |
| テスト | `test/data/models/album_test.dart` |

## 1. 責務

投稿をテーマ・イベント単位でまとめるアルバム 1 件を表すイミュータブルなデータクラス。`albums/{albumId}` ドキュメントとの相互変換を担う。投稿そのものは持たず、投稿 ID のリストで参照する。

## 2. 構成要素（クラス・関数・定数の一覧）

| 名前 | 種別 | 概要 |
|---|---|---|
| `Album` | クラス | アルバムのモデル |
| `Album.fromSnapshot` | factory コンストラクタ | Firestore のマップからの生成 |
| `Album.toMap` | メソッド | Firestore 書き込み用マップへの変換 |

定数はなし。

## 3. 公開インターフェース（コンストラクタ引数・プロパティ・メソッドのシグネチャと説明）

```dart
const Album({
  required String id,
  required String ownerId,
  required String title,
  required String description,
  required DateTime createdAt,
  List<String> postIds = const [],
  String? coverImageUrl,
})
```

| プロパティ | 型 | 説明 |
|---|---|---|
| `id` | `String` | ドキュメント ID。新規作成時は `''` |
| `ownerId` | `String` | 作成者（所有者）の UID |
| `title` | `String` | タイトル |
| `description` | `String` | 説明。欠損時は `''` |
| `postIds` | `List<String>` | 含まれる投稿 ID。並び順は追加順。欠損時は `[]` |
| `coverImageUrl` | `String?` | カバー画像 URL。未設定は `null` |
| `createdAt` | `DateTime` | 作成日時 |

| メソッド | 説明 |
|---|---|
| `factory Album.fromSnapshot(String id, Map<String, dynamic> document)` | ドキュメント ID とデータから生成 |
| `Map<String, dynamic> toMap()` | `id` を除く全フィールドをマップに変換 |

## 4. 内部状態（フィールド・状態遷移）

すべて `final`。状態遷移なし。`copyWith` は持たない（更新は Repository がフィールド単位で行う）。

## 5. 処理詳細（メソッドごとの手順・分岐・呼び出す Repository/SDK）

### `Album.fromSnapshot`

1. `ownerId` / `title` / `description` は `document['x'] ?? ''`。
2. `postIds` は `List<String>.from(document['postIds'] ?? [])`（コピーを作るため元マップと共有しない）。
3. `coverImageUrl` は `document['coverImageUrl']` をそのまま（欠損時 `null`）。
4. `createdAt` は `(document['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now()`。

### `toMap`

`ownerId`, `title`, `description`, `postIds`, `coverImageUrl`（null でも**キーを出力**する）, `createdAt`（`Timestamp.fromDate`）を返す。`id` は含めない。

## 6. データ仕様（読み書きする Firestore/Storage のパス・フィールド、定数値）

パス: `albums/{albumId}`

| フィールド | Firestore 型 | Dart 型 | 欠損時の既定値 |
|---|---|---|---|
| `ownerId` | string | `String` | `''` |
| `title` | string | `String` | `''` |
| `description` | string | `String` | `''` |
| `postIds` | array&lt;string&gt; | `List<String>` | `[]` |
| `coverImageUrl` | string / null | `String?` | `null` |
| `createdAt` | Timestamp | `DateTime` | `DateTime.now()` |

## 7. 例外・エラー処理（例外の扱い・戻り値・表示メッセージ）

- `createdAt` が `Timestamp` 以外なら `as Timestamp?` で `TypeError`。
- `postIds` に文字列以外の要素があると `List<String>.from` で `TypeError`。
- `coverImageUrl` が文字列以外なら代入時に型エラー。
- いずれも捕捉しない。

## 8. テスト観点（既存テストが確認していること / 未テストの観点）

既存（`album_test.dart`）:
- 全フィールドを持つドキュメントのマッピング。
- 空マップでの既定値フォールバック（`ownerId` / `title` / `description` が `''`、`postIds` が空、`coverImageUrl` が null、`createdAt` が `DateTime`）。
- `toMap` が `createdAt` を `Timestamp` にし、null のカバーを保持し、`id` を含めないこと。
- `fromSnapshot` との往復で値が保たれること。

未テスト: 型不一致時の挙動。

## 9. 備考・既知の課題

- カバー画像を設定する UI はないため、`coverImageUrl` は実運用では常に `null`（基本設計 7 章）。
- `createdAt` 欠損時の `DateTime.now()` は読み取りごとに値が変わり、一覧の並び順が不安定になり得る。
