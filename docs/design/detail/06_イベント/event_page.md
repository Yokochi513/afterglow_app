# lib/ui/event/event_page.dart

| 項目 | 内容 |
|---|---|
| ファイル | `lib/ui/event/event_page.dart` |
| 基本設計 | [06 イベント](../../06_イベント.md) の「2. 画面・コンポーネント構成」（EventPage）「3. 処理フロー」（一覧・作成） |
| 関連する基本設計 | [00 システム概要](../../00_システム概要.md)（下部タブ） |
| レイヤ | View |
| 主な依存先 | `lib/data/models/event.dart`, `lib/data/models/app_user.dart`, `lib/data/repositories/event_repository.dart`, `lib/data/repositories/user_repository.dart`, `lib/ui/event/event_detail_page.dart`, `lib/ui/event/widgets/event_edit_dialog.dart`, `lib/ui/core/widgets/event_schedule_text.dart`, `package:provider` |
| 主な利用元 | `lib/app/main_shell.dart`（タブ 3: Event） |
| テスト | なし |

## 1. 責務

- 全イベントを開催日時の昇順で一覧表示する（Event タブの本体）。
- FAB からイベント作成ダイアログ（`EventEditDialog`）を開く。
- 行タップでイベント詳細（`EventDetailPage`）へ遷移する。

## 2. 構成要素

| 種別 | 名前 | 概要 |
|---|---|---|
| クラス | `EventPage extends StatelessWidget` | 画面本体 |
| private クラス | `_EventTile extends StatelessWidget` | 一覧の 1 行 |

## 3. 公開インターフェース

```dart
const EventPage({Key? key});
```

引数なし。`MainShell` の `IndexedStack` に `const` で置かれる。

## 4. 内部状態

なし（StatelessWidget）。表示内容は `StreamBuilder` が保持する。

## 5. 処理詳細

### 5.1 ウィジェット構成

```
Scaffold
├─ AppBar(title: 'イベント')
├─ FloatingActionButton(tooltip: 'イベントを作成', Icon(Icons.add))
└─ body: StreamBuilder<List<Event>>(stream: EventRepository.getEvents())
     ├─ waiting → Center(CircularProgressIndicator)
     ├─ 0 件   → Center(Text('まだイベントがありません'))
     └─ ListView.separated(padding: 縦 8, separator: Divider(height: 1))
          └─ _EventTile(event)
```

### 5.2 `EventPage.build`

1. `context.read<EventRepository>()` を取得。
2. FAB の `onPressed` で `showDialog<bool>(builder: (_) => const EventEditDialog())` を開く（新規作成モード）。戻り値は使わない（一覧はストリームで自動反映）。
3. `StreamBuilder` の分岐:
   - `connectionState == waiting` → インジケータ。
   - `snapshot.data ?? []` が空 → 「まだイベントがありません」。
   - それ以外 → `ListView.separated`。

### 5.3 `_EventTile.build`

```
ListTile(isThreeLine: true)
├─ leading: Icon(Icons.event_outlined)
├─ title: Text(event.title, maxLines: 1, ellipsis)
├─ subtitle: Column
│   ├─ Text(EventScheduleText.formatDateTime(event.startAt))   ← 開始日時のみ
│   └─ StreamBuilder<AppUser?>(UserRepository.watchUser(event.organizerId))
│        └─ Text('主催: $organizer$place', maxLines: 1, ellipsis)
└─ onTap: Navigator.push(MaterialPageRoute(EventDetailPage(eventId: event.id)))
```

- `organizer`: `snapshot.data?.username ?? ''` が空なら `'名無しさん'`、それ以外はユーザー名。読み込み中も `'名無しさん'` が出る。
- `place`: `event.locationName` が空なら `''`、あれば `'・${locationName}'`。
- 行ごとに主催者の `users/{uid}` を購読する。

## 6. データ仕様

| 読み取り | 経由 |
|---|---|
| `events`（`startAt` 昇順・全件） | `EventRepository.getEvents()` |
| `users/{organizerId}` | `UserRepository.watchUser()`（行ごと） |

書き込みはしない（作成はダイアログ側）。

## 7. 例外・エラー処理

- `getEvents` のストリームがエラーになった場合、`snapshot.data` が null のため「まだイベントがありません」と表示される（エラー専用の表示はない）。
- 主催者の取得失敗時も `'名無しさん'` 表示になる。

## 8. テスト観点

ウィジェットテストはない。未テストの観点:

- 0 件表示、`startAt` 昇順の並び、主催者名・集合場所の連結表示、名無しさんフォールバック。
- FAB で作成ダイアログが開くこと、行タップで詳細へ遷移すること。

## 9. 備考・既知の課題

- 一覧の日時は**開始日時のみ**で、終了日時（`formatRange`）は詳細画面でのみ表示する。
- 過去のイベントも含めて全件を昇順で表示するため、古いイベントが先頭に並ぶ（基本設計 7 章）。
- 主催者名を行ごとに個別購読するため、件数が増えると購読数も比例して増える。
