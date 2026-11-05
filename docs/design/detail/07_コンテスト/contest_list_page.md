# lib/ui/contest/contest_list_page.dart

| 項目 | 内容 |
|---|---|
| ファイル | `lib/ui/contest/contest_list_page.dart` |
| 基本設計 | [07 コンテスト](../../07_コンテスト.md) の「3. 画面・コンポーネント構成」（ContestListPage） |
| 関連する基本設計 | [00 システム概要](../../00_システム概要.md)（下部タブ） |
| レイヤ | View |
| 主な依存先 | `lib/data/models/contest.dart`, `lib/data/repositories/contest_repository.dart`, `lib/ui/contest/contest_detail_page.dart`, `lib/ui/contest/widgets/contest_edit_dialog.dart`, `lib/ui/core/widgets/event_schedule_text.dart`, `package:provider` |
| 主な利用元 | `lib/app/main_shell.dart`（タブ index 4「Contest」） |
| テスト | なし |

## 1. 責務

下部タブ「Contest」の画面。全コンテストを応募締切の昇順で一覧表示し、行タップで詳細画面へ、FAB で作成ダイアログへ遷移する。

## 2. 構成要素（クラス・関数・定数の一覧）

| 名前 | 種別 | 概要 |
|---|---|---|
| `ContestListPage` | `StatelessWidget`（公開） | 一覧画面 |
| `_ContestTile` | `StatelessWidget` | 1 行分の `ListTile` |
| `_phaseLabel(ContestPhase)` | トップレベル関数（private） | フェーズの表示名 |

## 3. 公開インターフェース（コンストラクタ引数・プロパティ・メソッドのシグネチャと説明）

```dart
const ContestListPage({super.key})
```

引数なし。`ContestRepository` は `context.read<ContestRepository>()` で取得する。

## 4. 内部状態（フィールド・状態遷移）

State を持たない。表示状態は `StreamBuilder<List<Contest>>` の `snapshot` で決まる。

| snapshot | 表示 |
|---|---|
| `connectionState == waiting` | 中央に `CircularProgressIndicator` |
| `data` が空 / `null` | 中央に「まだコンテストがありません」 |
| 1 件以上 | `ListView.separated` |

## 5. 処理詳細（メソッドごとの手順・分岐・呼び出す Repository/SDK）

### ウィジェット構成

```
Scaffold
├─ AppBar(title: 'Contest')
├─ FloatingActionButton(tooltip: 'コンテストを作成', icon: Icons.add)
└─ StreamBuilder<List<Contest>>(stream: ContestRepository.getContests())
   └─ ListView.separated(padding: 縦 8, separator: Divider(height: 1))
      └─ _ContestTile × n
         └─ ListTile
            ├─ leading: Icon(Icons.emoji_events_outlined)
            ├─ title: contest.title（1 行・省略）
            ├─ subtitle: '{フェーズ} / 応募締切 {yyyy/MM/dd HH:mm}'（2 行まで・省略）
            └─ trailing: Icon(Icons.chevron_right)
```

### イベントハンドラ

| 操作 | 処理 |
|---|---|
| FAB 押下 | `showDialog<bool>(builder: (_) => const ContestEditDialog())`（新規作成モード）。戻り値は使わない（一覧はストリームで自動更新） |
| 行タップ | `Navigator.push(MaterialPageRoute(builder: (_) => ContestDetailPage(contestId: contest.id)))` |

### `_phaseLabel(phase)`

| `ContestPhase` | 表示 |
|---|---|
| `entry` | 応募受付中 |
| `voting` | 投票受付中 |
| `ended` | 終了 |

フェーズは `contest.phase`（ビルド時の端末時刻）で判定する。日時は `EventScheduleText.formatDateTime`（`yyyy/MM/dd HH:mm`）で整形する。

## 6. データ仕様（読み書きする Firestore/Storage のパス・フィールド、定数値）

`ContestRepository.getContests()` 経由で `contests` を `entryDeadline` 昇順に購読する。書き込みは無い。

## 7. 例外・エラー処理（例外の扱い・戻り値・表示メッセージ）

- `snapshot.hasError` を見ていない。ストリームがエラーになると `data` が `null` となり「まだコンテストがありません」と表示される。

## 8. テスト観点（既存テストが確認していること / 未テストの観点）

既存テストは無い。

未テストの観点:

- 0 件時の文言、行のサブタイトル（フェーズ・応募締切）の書式。
- FAB でダイアログが開くこと、行タップで詳細へ遷移すること。

## 9. 備考・既知の課題

- 一覧のフェーズ表示は再ビルド時にしか更新されない。画面を開いたまま締切を迎えてもラベルは変わらない。
- `_phaseLabel` は `contest_detail_page.dart` にも同じ実装が重複している。
- 終了済みコンテストも区別なく並ぶ（フィルタ・ページングなし）。
