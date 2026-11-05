# lib/ui/info/widgets/release_note_dialog.dart

| 項目 | 内容 |
|---|---|
| ファイル | `lib/ui/info/widgets/release_note_dialog.dart` |
| 基本設計 | [10 お知らせ・使い方ガイド・フィードバック](../../10_お知らせ・使い方ガイド.md) の「2. 画面・コンポーネント構成」（ReleaseNoteDialog）「3.1 起動時の案内」 |
| 関連する基本設計 | なし |
| レイヤ | View |
| 主な依存先 | `lib/data/models/release_note.dart`, `lib/ui/info/widgets/release_note_view.dart` |
| 主な利用元 | `lib/ui/map/map_screen.dart`（`_maybeAnnounce`） |
| テスト | なし |

## 1. 責務

アップデート後の初回起動で自動表示する「What's New」ダイアログ。1 バージョン分のリリースノートを表示する。

## 2. 構成要素（クラス・関数・定数の一覧）

| 名前 | 種別 | 概要 |
|---|---|---|
| `ReleaseNoteDialog` | `StatelessWidget`（公開） | ダイアログ |
| `ReleaseNoteDialog.show` | `static` メソッド | 表示し、閉じられたら完了する |

## 3. 公開インターフェース（コンストラクタ引数・プロパティ・メソッドのシグネチャと説明）

```dart
const ReleaseNoteDialog({super.key, required ReleaseNote releaseNote})
static Future<void> show(BuildContext context, ReleaseNote releaseNote)
```

`show` は `showDialog<void>(context: context, builder: (_) => ReleaseNoteDialog(releaseNote: releaseNote))` を返す。

## 4. 内部状態（フィールド・状態遷移）

なし。

## 5. 処理詳細（メソッドごとの手順・分岐・呼び出す Repository/SDK）

### ウィジェット構成

```
AlertDialog
├─ title: Row
│  ├─ Icon(Icons.campaign_outlined, primary 色)
│  ├─ SizedBox(8)
│  └─ Expanded(Text('新しくなりました'))
├─ content: SizedBox(width: double.maxFinite) → SingleChildScrollView → Column(start, min)
│  ├─ Text('バージョン {version}' + date があれば '（{date}）', labelMedium・outline 色)
│  ├─ SizedBox(12)
│  └─ ReleaseNoteView(releaseNote)
└─ actions: TextButton('閉じる') → Navigator.pop()
```

表示例: CHANGELOG の見出しが `## [1.6.0+7] - 2026-10-16` なら「バージョン 1.6.0+7（2026-10-16）」。

### 呼び出し側

`MapScreen._maybeAnnounce` が `ReleaseNoteRepository.shouldAnnounce()` → `announcementNote()` の結果が `null` でなく mounted のときに `await ReleaseNoteDialog.show(context, note)` し、閉じた後に `markAnnounced()` を呼ぶ。

## 6. データ仕様（読み書きする Firestore/Storage のパス・フィールド、定数値）

なし（既読記録は呼び出し側が行う）。

## 7. 例外・エラー処理（例外の扱い・戻り値・表示メッセージ）

なし。

## 8. テスト観点（既存テストが確認していること / 未テストの観点）

既存テストは無い。

未テストの観点: タイトル・バージョン表記（日付の有無）・「閉じる」で閉じること。

## 9. 備考・既知の課題

- バリア（背景）タップでも閉じられる（`showDialog` の既定）。閉じ方に関係なく既読になる。
