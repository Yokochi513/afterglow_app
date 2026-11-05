# lib/ui/notification/widgets/notification_bell.dart

| 項目 | 内容 |
|---|---|
| ファイル | `lib/ui/notification/widgets/notification_bell.dart` |
| 基本設計 | [08 通知](../../08_通知.md) の「4. 画面・コンポーネント構成」（NotificationBell） |
| 関連する基本設計 | [02 地図・投稿作成](../../02_地図・投稿作成.md)（Map タブの AppBar に配置） |
| レイヤ | View |
| 主な依存先 | `lib/data/repositories/auth_repository.dart`, `lib/data/repositories/notification_repository.dart`, `lib/ui/notification/notification_page.dart`, `package:provider` |
| 主な利用元 | `lib/ui/map/map_screen.dart`（AppBar の `actions` 先頭） |
| テスト | なし |

## 1. 責務

- AppBar に置くベルアイコン。ログイン中ユーザーの未読通知件数をバッジで表示する。
- タップで `NotificationPage` を開く。

## 2. 構成要素

| 種別 | 名前 | 概要 |
|---|---|---|
| クラス | `NotificationBell extends StatelessWidget` | 本体 |
| ローカル関数 | `open()` | `NotificationPage` を push |

## 3. 公開インターフェース

```dart
const NotificationBell({Key? key});
```

## 4. 内部状態

なし（StatelessWidget）。未読件数は `StreamBuilder` が保持する。

## 5. 処理詳細

### 5.1 `build`

1. `uid = context.read<AuthRepository>().currentUserId`、`notifications = context.read<NotificationRepository>()`。
2. `open()`: `Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const NotificationPage()))`。
3. `uid == null` のとき: `IconButton(icon: Icon(Icons.notifications_none), tooltip: '通知', onPressed: open)`（購読しない）。
4. それ以外: `StreamBuilder<int>(stream: notifications.watchUnreadCount(uid))`。

| 項目 | `unread > 0` | `unread == 0`（読み込み中を含む） |
|---|---|---|
| tooltip | `'通知（未読 $unread 件）'` | `'通知'` |
| アイコン | `Icons.notifications` | `Icons.notifications_none` |
| バッジ | 表示（`isLabelVisible: true`） | 非表示 |
| バッジ文字 | `unread > 99` なら `'99+'`、それ以外は件数 | — |

`unread = snapshot.data ?? 0`。

## 6. データ仕様

| 読み取り | 経由 |
|---|---|
| `notifications`（`recipientId == uid` かつ `isRead == false`）の件数 | `NotificationRepository.watchUnreadCount` |

## 7. 例外・エラー処理

ストリームがエラーになった場合は `snapshot.data` が null となり、未読 0 件と同じ表示になる（エラー表示はない）。

## 8. テスト観点

ウィジェットテストはない。未テストの観点:

- 未読 0 / 1〜99 / 100 以上でのバッジ表示と tooltip。
- 未ログイン時に購読せずアイコンだけ出すこと。
- タップで通知一覧へ遷移すること。

## 9. 備考・既知の課題

- `uid` は `build` 時に一度だけ読む。ログイン状態の変化は `AuthGate` による画面の作り直しで反映される前提。
- 未読件数は未読ドキュメント全件の購読で数える（[notification_repository.md](notification_repository.md) 9 章）。
