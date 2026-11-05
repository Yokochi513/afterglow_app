# lib/ui/info/widgets/usage_guide_dialog.dart

| 項目 | 内容 |
|---|---|
| ファイル | `lib/ui/info/widgets/usage_guide_dialog.dart` |
| 基本設計 | [10 お知らせ・使い方ガイド・フィードバック](../../10_お知らせ・使い方ガイド.md) の「2. 画面・コンポーネント構成」（UsageGuideDialog）「3.1 起動時の案内」 |
| 関連する基本設計 | なし |
| レイヤ | View |
| 主な依存先 | `lib/ui/info/widgets/usage_guide_view.dart` |
| 主な利用元 | `lib/ui/map/map_screen.dart`（`_maybeShowUsageGuide`） |
| テスト | `test/ui/info/usage_guide_page_test.dart` |

## 1. 責務

初回起動で 1 回だけ自動表示する使い方ガイド（Issue #47）のダイアログ。本文は `UsageGuideView` を使う。

## 2. 構成要素（クラス・関数・定数の一覧）

| 名前 | 種別 | 概要 |
|---|---|---|
| `UsageGuideDialog` | `StatelessWidget`（公開） | ダイアログ |
| `UsageGuideDialog.show` | `static` メソッド | 表示し、閉じられたら完了する |

## 3. 公開インターフェース（コンストラクタ引数・プロパティ・メソッドのシグネチャと説明）

```dart
const UsageGuideDialog({super.key})
static Future<void> show(BuildContext context)
```

`show` は `showDialog<void>(context: context, builder: (_) => const UsageGuideDialog())` を返す。

## 4. 内部状態（フィールド・状態遷移）

なし。

## 5. 処理詳細（メソッドごとの手順・分岐・呼び出す Repository/SDK）

### ウィジェット構成

```
AlertDialog
├─ title: Row
│  ├─ Icon(Icons.help_outline, primary 色)
│  ├─ SizedBox(8)
│  └─ Expanded(Text('Afterglow の使い方'))
├─ content: SizedBox(width: double.maxFinite) → SingleChildScrollView → UsageGuideView()
└─ actions: TextButton('はじめる') → Navigator.pop()
```

### 呼び出し側

`MapScreen` は初回描画後（`addPostFrameCallback`）に `_maybeShowUsageGuide` を実行し、`UsageGuideRepository.shouldShowGuide()` が `true` なら `await UsageGuideDialog.show(context)`、閉じた後に `markGuideShown()` と `ReleaseNoteRepository.markAnnounced()` を呼ぶ。ガイドを出した回はお知らせダイアログを出さない。

## 6. データ仕様（読み書きする Firestore/Storage のパス・フィールド、定数値）

なし（表示済み記録は呼び出し側が行う）。

## 7. 例外・エラー処理（例外の扱い・戻り値・表示メッセージ）

なし。

## 8. テスト観点（既存テストが確認していること / 未テストの観点）

既存（`test/ui/info/usage_guide_page_test.dart` の「ダイアログでも同じ内容を表示し、閉じられる」）:

- `show` で開いたダイアログに `UsageGuideView` の内容が出て、「はじめる」で閉じられる。

未テスト: `MapScreen` からの初回のみの自動表示（Repository 側のテストで判定ロジックのみ確認）。

## 9. 備考・既知の課題

- バリア（背景）タップでも閉じられる（`showDialog` の既定）。閉じ方に関係なく表示済みになる。
