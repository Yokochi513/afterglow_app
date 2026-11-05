# lib/ui/core/widgets/event_schedule_text.dart

| 項目 | 内容 |
|---|---|
| ファイル | `lib/ui/core/widgets/event_schedule_text.dart` |
| 基本設計 | [06 イベント](../../06_イベント.md) の「2. 画面・コンポーネント構成」（EventScheduleText） |
| 関連する基本設計 | [07 コンテスト](../../07_コンテスト.md)（締切日時の整形に `formatDateTime` を流用） |
| レイヤ | View（共通部品） |
| 主な依存先 | `lib/data/models/event.dart`, `package:flutter/material.dart` |
| 主な利用元 | `lib/ui/event/event_page.dart`, `lib/ui/event/event_detail_page.dart`, `lib/ui/event/widgets/event_edit_dialog.dart`, `lib/ui/contest/contest_list_page.dart`, `lib/ui/contest/contest_detail_page.dart`, `lib/ui/contest/widgets/contest_edit_dialog.dart` |
| テスト | なし |

## 1. 責務

- イベントの開催日時を 1 行のテキストで表示する。
- `intl` を使わずに日時を整形する static ヘルパー（`formatDateTime` / `formatTime` / `formatRange`）を提供する。イベント以外（コンテストの締切）からも使われる。

## 2. 構成要素

| 種別 | 名前 | 概要 |
|---|---|---|
| クラス | `EventScheduleText extends StatelessWidget` | 表示ウィジェット |
| static private | `_two(int n)` | 2 桁ゼロ埋め（`padLeft(2, '0')`） |
| static | `formatDateTime(DateTime)` | `yyyy/MM/dd HH:mm` |
| static | `formatTime(DateTime)` | `HH:mm` |
| static | `formatRange(Event)` | 開始〜終了の範囲文字列 |

## 3. 公開インターフェース

```dart
const EventScheduleText({Key? key, required Event event, TextStyle? style});

static String formatDateTime(DateTime time);
static String formatTime(DateTime time);
static String formatRange(Event event);
```

| 引数 | 説明 |
|---|---|
| `event` | 表示対象 |
| `style` | `Text` に渡すスタイル（省略可） |

## 4. 内部状態

なし（StatelessWidget）。

## 5. 処理詳細

### 5.1 `formatDateTime`

`'${year}/${_two(month)}/${_two(day)} ${_two(hour)}:${_two(minute)}'`。例: `2026/07/20 13:00`。年はゼロ埋めしない。ローカルタイム（`DateTime` の値そのまま）で整形する。

### 5.2 `formatTime`

`'${_two(hour)}:${_two(minute)}'`。例: `17:00`。

### 5.3 `formatRange`

1. `start = formatDateTime(event.startAt)`。
2. `event.endAt` が null なら `start` を返す。
3. `endAt` と `startAt` の年・月・日がすべて一致するか（`isSameDay`）を判定。
4. `'$start 〜 ${isSameDay ? formatTime(end) : formatDateTime(end)}'` を返す。

| 例 | 結果 |
|---|---|
| 終了なし | `2026/07/20 13:00` |
| 同日終了 | `2026/07/20 13:00 〜 17:00` |
| 翌日終了 | `2026/07/20 22:00 〜 2026/07/21 02:00` |

区切りは全角の「〜」（前後に半角スペース）。

### 5.4 `build`

`Text(formatRange(event), style: style)` を返す。

## 6. データ仕様

なし（Firestore を読み書きしない）。

## 7. 例外・エラー処理

なし。

## 8. テスト観点

専用のテストはない。未テストの観点:

- `formatRange` の終了なし / 同日 / 日またぎの 3 パターン。
- 1 桁の月・日・時・分のゼロ埋め。

## 9. 備考・既知の課題

- イベント専用の名前だが、`formatDateTime` はコンテスト画面からも使う共通整形関数になっている。
- 秒・曜日は表示しない。タイムゾーン変換はしない（端末のローカルタイム）。
