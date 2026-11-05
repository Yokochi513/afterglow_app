# lib/ui/core/widgets/contest_entry_badge.dart

| 項目 | 内容 |
|---|---|
| ファイル | `lib/ui/core/widgets/contest_entry_badge.dart` |
| 基本設計 | [07 コンテスト](../../07_コンテスト.md) の「3. 画面・コンポーネント構成」（ContestEntryBadge） |
| 関連する基本設計 | [03 フィード・投稿詳細](../../03_フィード・投稿詳細.md)（`PostCard`・投稿詳細での表示） |
| レイヤ | View（共通部品） |
| 主な依存先 | `lib/data/models/contest.dart`, `lib/data/repositories/contest_repository.dart`, `package:provider`, `dart:async` |
| 主な利用元 | `lib/ui/core/widgets/post_card.dart`, `lib/ui/post/widgets/post_detail_view.dart` |
| テスト | `test/ui/core/contest_entry_badge_test.dart` |

## 1. 責務

応募作品（`contestId` を持つ投稿）に付ける「{タイトル}参加中・n票」/「{タイトル}応募作品・n票」のチップ。コンテストを購読してタイトルと締切の変更・削除に追従し、表示中に投票締切を迎えたらタイマーで再描画して「応募作品」に切り替える。

## 2. 構成要素（クラス・関数・定数の一覧）

| 名前 | 種別 | 概要 |
|---|---|---|
| `ContestEntryBadge` | `StatefulWidget`（公開） | バッジ |
| `_ContestEntryBadgeState` | `State` | 購読・タイマー管理 |

## 3. 公開インターフェース（コンストラクタ引数・プロパティ・メソッドのシグネチャと説明）

```dart
const ContestEntryBadge({
  super.key,
  required String contestId,
  required int voteCount,
})
```

| 引数 | 説明 |
|---|---|
| `contestId` | 応募先コンテスト ID（`post.contestId!`） |
| `voteCount` | 得票数（`post.voteCount`）。購読はせず、親から渡された値を表示する |

## 4. 内部状態（フィールド・状態遷移）

| フィールド | 型 | 内容 |
|---|---|---|
| `_subscription` | `StreamSubscription<Contest?>?` | `watchContest` の購読 |
| `_deadlineTimer` | `Timer?` | 投票締切で再描画するタイマー |
| `_contest` | `Contest?` | 最新のコンテスト。未取得・削除・エラー時は `null` |

### ライフサイクル

| タイミング | 処理 |
|---|---|
| `initState` | `_subscribe()` |
| `didUpdateWidget` | `contestId` が変わったら購読とタイマーを取り消し、`_contest = null` にして再購読 |
| `dispose` | 購読とタイマーを取り消す |

## 5. 処理詳細（メソッドごとの手順・分岐・呼び出す Repository/SDK）

### `_subscribe()`

`context.read<ContestRepository>().watchContest(widget.contestId).listen(...)`。データは `_updateContest(contest)`、エラーは `_updateContest(null)` に渡す。

### `_updateContest(contest)`

1. unmounted なら何もしない。
2. 既存の `_deadlineTimer` を取り消す。
3. `setState` で `_contest = contest`。
4. `contest != null` かつ「投票締切 − 現在」が正なら、その残り時間で `Timer` を張り、発火時に mounted なら `setState(() {})` で再描画する。

応募締切ではタイマーを張らない（応募受付中と投票受付中はどちらも「参加中」で表示が変わらないため）。

### `build`

| 値 | 決め方 |
|---|---|
| `title` | `_contest` が `null` またはタイトルが空 → `'コンテスト'`、それ以外 → `contest.title` |
| `status` | `_contest` が `null` または `contest.phase == ended` → `'応募作品'`、それ以外 → `'参加中'` |

表示:

```
Chip(
  avatar: Icon(Icons.emoji_events_outlined, size: 16),
  label: Text('$title$status・${voteCount}票', maxLines: 1, ellipsis),
  labelStyle: textTheme.labelSmall,
  visualDensity: compact,
  materialTapTargetSize: shrinkWrap,
)
```

表示例: 「秋の写真コンテスト参加中・3票」「秋の写真コンテスト応募作品・3票」「コンテスト応募作品・3票」（読込前・削除後）。

## 6. データ仕様（読み書きする Firestore/Storage のパス・フィールド、定数値）

`ContestRepository.watchContest` 経由で `contests/{contestId}` を購読する（`title`・`entryDeadline`・`votingDeadline` を使用）。書き込みは無い。

## 7. 例外・エラー処理（例外の扱い・戻り値・表示メッセージ）

- 購読エラー（権限不足など）は `null` 扱いにし、「コンテスト応募作品・n票」を表示する。
- 非同期コールバックはすべて `mounted` を確認してから `setState` する。

## 8. テスト観点（既存テストが確認していること / 未テストの観点）

既存（`test/ui/core/contest_entry_badge_test.dart`。`ContestPhase` の 3 値それぞれで実行）:

- 応募受付中・投票受付中は「秋の写真コンテスト参加中・3票」、終了は「秋の写真コンテスト応募作品・3票」を表示する。
- 締切を過去へ更新すると「秋の写真コンテスト応募作品・3票」に切り替わる。
- コンテストを削除すると「コンテスト応募作品・3票」に切り替わる。

未テスト:

- 投票締切到達時のタイマーによる再描画。
- `contestId` 変更時の再購読。

## 9. 備考・既知の課題

- 読み込み中（最初のスナップショット到着前）も `_contest == null` のため「コンテスト応募作品」と表示され、直後に「参加中」へ変わることがある。
- `PostCard` が並ぶ一覧ではバッジ 1 つにつき `contests/{id}` の購読が 1 本張られる（同じコンテストでも共有しない）。
- `voteCount` は親から渡された `Post` の値で、本部品は得票数を購読しない。得票の変化が反映されるかは親の投稿取得方法（ストリームか一度きりの取得か）に依存する。
