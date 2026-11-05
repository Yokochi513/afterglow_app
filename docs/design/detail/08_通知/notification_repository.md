# lib/data/repositories/notification_repository.dart

| 項目 | 内容 |
|---|---|
| ファイル | `lib/data/repositories/notification_repository.dart` |
| 基本設計 | [08 通知](../../08_通知.md) の「4. 画面・コンポーネント構成」「6. データ設計」「7. 権限・セキュリティ」 |
| 関連する基本設計 | なし |
| レイヤ | Repository |
| 主な依存先 | `lib/data/models/notification.dart`, `package:cloud_firestore` |
| 主な利用元 | `lib/app/dependencies.dart`（生成・提供）, `lib/ui/notification/notification_page.dart`, `lib/ui/notification/widgets/notification_bell.dart` |
| テスト | `test/data/repositories/notification_repository_test.dart`, `test/ui/notification/notification_page_test.dart`（間接） |

## 1. 責務

- 受信者本人宛ての通知一覧・未読件数の購読。
- 通知 1 件 / 全件の既読化。
- 週次メール通知の on/off（`users/{uid}/private/profile.emailNotification`）の購読と更新。
- 通知の作成・削除は行わない（Functions のみ。ルールでクライアントには禁止）。

## 2. 構成要素

| 種別 | 名前 | 値 / 概要 |
|---|---|---|
| クラス | `NotificationRepository` | 本体 |
| 定数 | `notificationsCollection` | `'notifications'` |
| 定数 | `usersCollection` | `'users'` |
| 定数 | `privateProfileDoc` | `'private/profile'` |
| 定数 | `listLimit` | `50` |
| private getter | `_notificationsRef` | `collection('notifications')` |
| private | `_recipientQuery(String userId)` | `where('recipientId', isEqualTo: userId)` |
| private | `_privateProfileRef(String userId)` | `doc('users/$userId/private/profile')` |

## 3. 公開インターフェース

```dart
NotificationRepository({FirebaseFirestore? firestore});
```

| シグネチャ | 説明 |
|---|---|
| `Stream<List<AppNotification>> getNotifications(String userId)` | 自分宛てを `createdAt` 降順・最大 50 件で購読 |
| `Stream<int> watchUnreadCount(String userId)` | 自分宛ての未読件数を購読 |
| `Future<void> markAsRead(String notificationId)` | 1 件を既読化 |
| `Future<void> markAllAsRead(String userId)` | 未読を一括既読化 |
| `Stream<bool> watchEmailNotification(String userId)` | 週次メール設定を購読（未設定は true） |
| `Future<void> setEmailNotification(String userId, bool enabled)` | 週次メール設定を更新 |

## 4. 内部状態

| フィールド | 型 | 説明 |
|---|---|---|
| `_firestore` | `FirebaseFirestore` | 注入インスタンス（不変） |

## 5. 処理詳細

### 5.1 `getNotifications`

`_recipientQuery(userId).orderBy('createdAt', descending: true).limit(50).snapshots()` を購読し、`AppNotification.fromSnapshot(doc.id, doc.data())` のリスト（`growable: false`）を流す。複合インデックス `notifications(recipientId ASC, createdAt DESC)`（`firestore.indexes.json`）を使う。

### 5.2 `watchUnreadCount`

`_recipientQuery(userId).where('isRead', isEqualTo: false).snapshots()` を購読し、`snapshot.docs.length` を流す。件数上限はない（未読全件のドキュメントを購読して数える）。

### 5.3 `markAsRead`

`_notificationsRef.doc(notificationId).update({'isRead': true})` の Future をそのまま返す。

### 5.4 `markAllAsRead`

1. `_recipientQuery(userId).where('isRead', isEqualTo: false).get()`。
2. 0 件なら何もせず終了。
3. `WriteBatch` を作り、各ドキュメントに `update(doc.reference, {'isRead': true})`。
4. `batch.commit()`。

未読が 500 件を超えると Firestore のバッチ上限で失敗する（分割しない）。

### 5.5 `watchEmailNotification`

`_privateProfileRef(userId).snapshots()` を購読し、`snapshot.data()?['emailNotification'] ?? true` を流す（ドキュメントやフィールドが無ければ true）。

### 5.6 `setEmailNotification`

`_privateProfileRef(userId).set({'emailNotification': enabled}, SetOptions(merge: true))`。`email` 等の既存フィールドは保持する。

## 6. データ仕様

| 操作 | パス | フィールド |
|---|---|---|
| 読み取り | `notifications`（`recipientId == uid`、`createdAt` 降順、50 件） | 全フィールド |
| 読み取り | `notifications`（`recipientId == uid` かつ `isRead == false`） | 件数のみ使用 |
| 更新 | `notifications/{id}` | `isRead: true` のみ |
| 読み書き | `users/{uid}/private/profile` | `emailNotification`（bool、merge 書き込み） |

ルール: notifications の読み取りは承認済みかつ `recipientId == 自分`、更新は `isRead` だけを true にする変更のみ。`private/**` は本人のみ読み書き可。

## 7. 例外・エラー処理

すべてのメソッドで例外を捕捉しない。権限エラー・通信エラーはストリームのエラー / Future の失敗として呼び出し元に伝わる。

## 8. テスト観点

既存テスト（`notification_repository_test.dart`）が確認していること:

- `getNotifications` が受信者の通知だけを新しい順に返す。
- `watchUnreadCount` が自分宛ての未読だけを数える。
- `markAsRead` が `isRead` を true にする。
- `markAllAsRead` が自分宛ての未読をすべて既読にし、他人宛てには影響しない。
- メール通知設定が未設定で true、`setEmailNotification(false)` で false になり、既存の `email` フィールドが残る。

ルールは `test/rules/notifications.test.mjs` が確認（本人のみ読める・既読化のみ可・作成削除不可）。

未テストの観点:

- `listLimit`（50 件）での打ち切り。
- 未読 500 件超の `markAllAsRead`。

## 9. 備考・既知の課題

- 未読件数は未読ドキュメントを全件購読して数える（集計クエリ `count()` は使っていない）。通知は削除されないため、未読が溜まると読み取り量が増える。
- メール通知設定は通知機能の Repository に置かれているが、保存先は `users/{uid}/private/profile`（ユーザーの非公開プロフィール）である。
