# lib/data/models/notification.dart

| 項目 | 内容 |
|---|---|
| ファイル | `lib/data/models/notification.dart` |
| 基本設計 | [08 通知](../../08_通知.md) の「2. 通知の発生条件」「6. データ設計」 |
| 関連する基本設計 | なし |
| レイヤ | Model |
| 主な依存先 | `package:cloud_firestore`（`Timestamp`） |
| 主な利用元 | `lib/data/repositories/notification_repository.dart`, `lib/ui/notification/notification_page.dart` |
| テスト | `test/data/models/notification_test.dart` |

## 1. 責務

- `notifications/{notificationId}` ドキュメントを表すイミュータブルなデータクラス `AppNotification` を提供する（Flutter の `Notification` クラスとの衝突を避けた命名）。
- 通知種別の定数と、遷移先の種類（投稿 / イベント）の判定を提供する。
- 通知の生成は Cloud Functions（[functions_index.md](../00_システム概要/functions_index.md)）が行う。クライアントは読み取りと既読化のみ。

## 2. 構成要素

| 種別 | 名前 | 値 / 概要 |
|---|---|---|
| クラス | `AppNotification` | 通知 1 件 |
| 定数 | `typeReaction` | `'reaction'`（`sourceId` は postId） |
| 定数 | `typeComment` | `'comment'`（`sourceId` は postId） |
| 定数 | `typeEventUpdate` | `'event_update'`（`sourceId` は eventId） |

## 3. 公開インターフェース

```dart
const AppNotification({
  required String id,
  required String recipientId,
  required String actorId,
  required String type,
  required String sourceId,
  bool isRead = false,
  required DateTime createdAt,
});
```

| メンバー | 型 | 説明 |
|---|---|---|
| `id` | `String` | ドキュメント ID |
| `recipientId` | `String` | 受信者 UID（クエリ条件） |
| `actorId` | `String` | 通知を起こしたユーザー UID |
| `type` | `String` | 上記 3 種のいずれか（未知の値もそのまま保持） |
| `sourceId` | `String` | postId または eventId |
| `isRead` | `bool` | 既読フラグ（既定 false） |
| `createdAt` | `DateTime` | 作成日時 |
| `targetsPost` | `bool`（getter） | `type == typeReaction \|\| type == typeComment` |
| `targetsEvent` | `bool`（getter） | `type == typeEventUpdate` |
| `AppNotification.fromSnapshot(String id, Map<String, dynamic> document)` | factory | Firestore から生成 |
| `toMap()` | `Map<String, dynamic>` | Firestore 形式のマップ（`id` は含まない） |

## 4. 内部状態

すべて `final`。生成後に変化しない。

## 5. 処理詳細

### 5.1 `fromSnapshot`

| フィールド | 欠損時 |
|---|---|
| `recipientId`, `actorId`, `type`, `sourceId` | `''` |
| `isRead` | false |
| `createdAt` | `Timestamp?` を `toDate()`、null なら `DateTime.now()` |

`type` が `''` や未知の値のとき、`targetsPost` / `targetsEvent` はどちらも false。

### 5.2 `toMap`

`{'recipientId', 'actorId', 'type', 'sourceId', 'isRead', 'createdAt': Timestamp.fromDate(createdAt)}`。アプリ本体では使わず、テストで通知ドキュメントを用意するのに使う。

## 6. データ仕様

| パス | フィールド | 型 |
|---|---|---|
| `notifications/{notificationId}` | `recipientId`, `actorId`, `type`, `sourceId` | string |
| | `isRead` | bool |
| | `createdAt` | Timestamp（Functions がサーバー時刻で設定） |

## 7. 例外・エラー処理

- `createdAt` が `Timestamp` 以外の型だとキャストで `TypeError`。
- 欠損フィールドは既定値に置き換え、例外にしない。

## 8. テスト観点

既存テスト（`test/data/models/notification_test.dart`）が確認していること:

- `fromSnapshot` が全フィールドを読む / 欠損時に既定値へフォールバックする。
- `event_update` が `targetsEvent` かつ `targetsPost` でないこと。
- `toMap` と `fromSnapshot` の往復。

未テストの観点:

- 未知の `type` で `targetsPost` / `targetsEvent` がともに false になること。

## 9. 備考・既知の課題

- 種別の文字列は Functions 側の `NotificationType` と二重に定義されている（同期は手作業）。
- `createdAt` 欠損時に `DateTime.now()` になるため、Functions のサーバー時刻が未確定のスナップショットでは並び・表示時刻が一時的にずれうる（通常 Functions が書くため確定済みで届く）。
