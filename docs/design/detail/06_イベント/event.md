# lib/data/models/event.dart

| 項目 | 内容 |
|---|---|
| ファイル | `lib/data/models/event.dart` |
| 基本設計 | [06 イベント](../../06_イベント.md) の「4. データ設計」 |
| 関連する基本設計 | [08 通知](../../08_通知.md)（`event_update` 通知の比較対象フィールド） |
| レイヤ | Model |
| 主な依存先 | `package:cloud_firestore`（`Timestamp`） |
| 主な利用元 | `lib/data/repositories/event_repository.dart`, `lib/ui/event/event_page.dart`, `lib/ui/event/event_detail_page.dart`, `lib/ui/event/widgets/event_edit_dialog.dart`, `lib/ui/core/widgets/event_schedule_text.dart` |
| テスト | `test/data/models/event_test.dart` |

## 1. 責務

- `events/{eventId}` ドキュメントを表すイミュータブルなデータクラス `Event` を提供する。
- `events/{eventId}/participants/{userId}` ドキュメントを表すイミュータブルなデータクラス `EventParticipant` を提供する。
- Firestore の `Map<String, dynamic>` との相互変換（`fromSnapshot` / `toMap`）と、欠損フィールドの既定値フォールバックを担う。

## 2. 構成要素

| 種別 | 名前 | 概要 |
|---|---|---|
| クラス | `Event` | イベント本体 |
| クラス | `EventParticipant` | 参加表明 1 件 |

定数（コレクション名など）は持たない。コレクション名は `EventRepository` 側の `static const` で定義する。

## 3. 公開インターフェース

### 3.1 `Event`

```dart
const Event({
  required String id,
  required String organizerId,
  required String title,
  required String description,
  required String locationName,
  required DateTime startAt,
  required DateTime createdAt,
  required DateTime updatedAt,
  double? latitude,
  double? longitude,
  DateTime? endAt,
});
```

| メンバー | 型 | 説明 |
|---|---|---|
| `id` | `String` | ドキュメント ID。新規作成時は `''` を渡すと `EventRepository.createEvent` が採番する |
| `organizerId` | `String` | 主催者 UID |
| `title` | `String` | イベント名 |
| `description` | `String` | 詳細。欠損時 `''` |
| `locationName` | `String` | 集合場所名。欠損時 `''` |
| `latitude` / `longitude` | `double?` | 集合場所の座標。地図で指定しなかった場合は null |
| `startAt` | `DateTime` | 開始日時 |
| `endAt` | `DateTime?` | 終了日時。未設定なら null |
| `createdAt` | `DateTime` | 作成日時 |
| `updatedAt` | `DateTime` | 更新日時 |
| `hasLocation` | `bool`（getter） | `latitude != null && longitude != null`。片方だけでは false |
| `Event.fromSnapshot(String id, Map<String, dynamic> document)` | factory | Firestore ドキュメントから生成 |
| `toMap()` | `Map<String, dynamic>` | Firestore に書くマップ（`id` は含まない） |

### 3.2 `EventParticipant`

```dart
const EventParticipant({
  required String userId,
  required DateTime joinedAt,
  String? comment,
});
```

| メンバー | 型 | 説明 |
|---|---|---|
| `userId` | `String` | 参加者 UID（ドキュメント ID と同一） |
| `comment` | `String?` | 参加コメント。未入力なら null |
| `joinedAt` | `DateTime` | 参加表明日時 |
| `EventParticipant.fromSnapshot(String id, Map<String, dynamic> document)` | factory | Firestore ドキュメントから生成 |
| `toMap()` | `Map<String, dynamic>` | Firestore に書くマップ |

## 4. 内部状態

すべて `final` フィールドで、生成後に変化しない。`copyWith` は持たない（編集時は `EventEditDialog` が新しい `Event` を組み立てる）。

## 5. 処理詳細

### 5.1 `Event.fromSnapshot`

1. `createdAt` を先に求める: `document['createdAt']` を `Timestamp?` として `toDate()`。null なら `DateTime.now()`。
2. 各フィールドを次のように詰める。

| フィールド | 変換 | 欠損時 |
|---|---|---|
| `organizerId` | そのまま | `''` |
| `title` | そのまま | `''` |
| `description` | そのまま | `''` |
| `locationName` | そのまま | `''` |
| `latitude` / `longitude` | `(as num?)?.toDouble()`（整数で保存されていても読める） | null |
| `startAt` | `Timestamp?` → `toDate()` | 手順 1 の `createdAt` |
| `endAt` | `Timestamp?` → `toDate()` | null |
| `createdAt` | 手順 1 の値 | `DateTime.now()` |
| `updatedAt` | `Timestamp?` → `toDate()` | 手順 1 の `createdAt`（旧データ対策） |

### 5.2 `Event.toMap`

| キー | 値 |
|---|---|
| `organizerId`, `title`, `description`, `locationName` | そのまま |
| `latitude`, `longitude` | そのまま（null も**キーを残して** null を書く） |
| `startAt` | `Timestamp.fromDate(startAt)` |
| `endAt` | null なら null、あれば `Timestamp.fromDate(endAt!)` |
| `createdAt`, `updatedAt` | `Timestamp.fromDate(...)` |

`id` は含めない（ドキュメント ID で表すため）。

### 5.3 `EventParticipant.fromSnapshot`

| フィールド | 変換 | 欠損時 |
|---|---|---|
| `userId` | `document['userId']` | 引数 `id`（ドキュメント ID） |
| `comment` | そのまま | null |
| `joinedAt` | `Timestamp?` → `toDate()` | `DateTime.now()` |

### 5.4 `EventParticipant.toMap`

`{'userId': userId, 'comment': comment, 'joinedAt': Timestamp.fromDate(joinedAt)}`。`comment` が null でもキーを残す。

## 6. データ仕様

| パス | フィールド | 型 |
|---|---|---|
| `events/{eventId}` | `organizerId`, `title`, `description`, `locationName` | string |
| | `latitude`, `longitude` | number \| null |
| | `startAt`, `createdAt`, `updatedAt` | Timestamp |
| | `endAt` | Timestamp \| null |
| `events/{eventId}/participants/{userId}` | `userId` | string |
| | `comment` | string \| null |
| | `joinedAt` | Timestamp |

## 7. 例外・エラー処理

- 型が想定と異なるフィールド（例: `startAt` が文字列）は `as Timestamp?` のキャストで `TypeError` になる。呼び出し側（Repository のストリーム）で捕捉しないため、ストリームのエラーとして View に伝わる。
- 欠損フィールドは上記の既定値に置き換え、例外にしない。

## 8. テスト観点

既存テスト（`test/data/models/event_test.dart`）が確認していること:

- `Event.fromSnapshot` が全フィールドを読み取る / 欠損時に既定値へフォールバックする（`startAt`・`updatedAt` → `createdAt`）。
- 整数で保存された座標を `double` として読める。
- 片方の座標だけでは `hasLocation` が false。
- `Event.toMap` が全フィールドを書き、`fromSnapshot` と往復できる。任意項目は null のままキーを残す。`id` を含まない。
- `EventParticipant` の全フィールド読み取り、`userId` 欠損時のドキュメント ID フォールバック、往復、`comment` null のキー保持。

未テストの観点:

- 型不一致データ（`Timestamp` 以外）が来たときの挙動。

## 9. 備考・既知の課題

- `createdAt` 欠損時に `DateTime.now()` を使うため、同じドキュメントでも読み込むたびに値が変わる（`startAt` もそれに追従する）。
- `toMap` は `createdAt` を含むが、更新時は `EventRepository.updateEvent` が独自のマップを組むため `toMap` は作成時のみ使われる。
