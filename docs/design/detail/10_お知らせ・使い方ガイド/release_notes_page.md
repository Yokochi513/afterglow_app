# lib/ui/info/release_notes_page.dart

| 項目 | 内容 |
|---|---|
| ファイル | `lib/ui/info/release_notes_page.dart` |
| 基本設計 | [10 お知らせ・使い方ガイド・フィードバック](../../10_お知らせ・使い方ガイド.md) の「2. 画面・コンポーネント構成」（ReleaseNotesPage）「6. エラー処理」 |
| 関連する基本設計 | なし |
| レイヤ | View |
| 主な依存先 | `lib/data/models/release_note.dart`, `lib/data/repositories/release_note_repository.dart`, `lib/ui/info/widgets/release_note_view.dart`, `package:provider` |
| 主な利用元 | `lib/ui/map/map_screen.dart`（AppBar の「お知らせ」ボタン `_openReleaseNotes`） |
| テスト | なし |

## 1. 責務

Map タブ AppBar の「お知らせ」（`Icons.campaign_outlined`）から開く一覧画面。`CHANGELOG.md` の全バージョンを新しい順に、バージョン見出しと変更内容で表示する。

## 2. 構成要素（クラス・関数・定数の一覧）

| 名前 | 種別 | 概要 |
|---|---|---|
| `ReleaseNotesPage` | `StatelessWidget`（公開） | 画面本体 |
| `_ReleaseNoteEntry` | `StatelessWidget` | 1 バージョン分（見出し + 本文） |

## 3. 公開インターフェース（コンストラクタ引数・プロパティ・メソッドのシグネチャと説明）

```dart
const ReleaseNotesPage({super.key})
```

引数なし。`ReleaseNoteRepository` は `context.read` で取得する。`MapScreen` が `MaterialPageRoute` で push する。

## 4. 内部状態（フィールド・状態遷移）

State を持たない。`FutureBuilder<List<ReleaseNote>>`（`future: loadReleaseNotes()`）の状態で表示が決まる。

| snapshot | 表示 |
|---|---|
| `waiting` | 中央に `CircularProgressIndicator` |
| `hasError` | 中央に「お知らせを読み込めませんでした」 |
| 0 件 | 中央に「お知らせはまだありません」 |
| 1 件以上 | `ListView.separated` |

## 5. 処理詳細（メソッドごとの手順・分岐・呼び出す Repository/SDK）

### ウィジェット構成

```
Scaffold
├─ AppBar(title: 'お知らせ')
└─ FutureBuilder<List<ReleaseNote>>(future: ReleaseNoteRepository.loadReleaseNotes())
   └─ ListView.separated(padding: 16, separator: Divider(height: 32))
      └─ _ReleaseNoteEntry × n
         └─ Column(start)
            ├─ Row(baseline: alphabetic)
            │  ├─ Text(version, titleMedium・太字)
            │  └─ [date != null] SizedBox(8) + Text(date, labelMedium・outline 色)
            ├─ SizedBox(12)
            └─ ReleaseNoteView(releaseNote)
```

並び順は `parseChangelog` の記載順（CHANGELOG は新しい順に書く）。`hasChanges == false` のバージョンも見出しだけで表示される。

イベントハンドラは無い（閲覧のみ）。

## 6. データ仕様（読み書きする Firestore/Storage のパス・フィールド、定数値）

`ReleaseNoteRepository.loadReleaseNotes()` で同梱アセット `CHANGELOG.md` を読む。既読記録（`release_note_last_seen_version`）は読み書きしない。

## 7. 例外・エラー処理（例外の扱い・戻り値・表示メッセージ）

| 状況 | 表示 |
|---|---|
| 読込・解析の失敗 | お知らせを読み込めませんでした |
| リリース済みのノートが 0 件 | お知らせはまだありません |

## 8. テスト観点（既存テストが確認していること / 未テストの観点）

既存テストは無い（解析は `release_note_test.dart`、読み込みは `release_note_repository_test.dart` で確認）。

未テストの観点:

- 3 状態（エラー・0 件・一覧）の表示、日付が無いバージョンの見出し。

## 9. 備考・既知の課題

- `future` を `build` 内で生成しているため、再ビルドのたびに CHANGELOG を読み直す。
- この画面を開いても既読（`markAnnounced`）は記録しない。
