# lib/ui/info/usage_guide_page.dart

| 項目 | 内容 |
|---|---|
| ファイル | `lib/ui/info/usage_guide_page.dart` |
| 基本設計 | [10 お知らせ・使い方ガイド・フィードバック](../../10_お知らせ・使い方ガイド.md) の「2. 画面・コンポーネント構成」（UsageGuidePage） |
| 関連する基本設計 | なし |
| レイヤ | View |
| 主な依存先 | `lib/ui/info/widgets/usage_guide_view.dart` |
| 主な利用元 | `lib/ui/map/map_screen.dart`（AppBar の「使い方」ボタン） |
| テスト | `test/ui/info/usage_guide_page_test.dart` |

## 1. 責務

使い方ガイド（Issue #47）をいつでも読み返すための画面。初回起動のダイアログと同じ本文（`UsageGuideView`）を全画面で表示する。

## 2. 構成要素（クラス・関数・定数の一覧）

| 名前 | 種別 | 概要 |
|---|---|---|
| `UsageGuidePage` | `StatelessWidget`（公開） | 画面 |
| `UsageGuidePage.open` | `static` メソッド | この画面を push する |

## 3. 公開インターフェース（コンストラクタ引数・プロパティ・メソッドのシグネチャと説明）

```dart
const UsageGuidePage({super.key})
static Future<void> open(BuildContext context)
```

`open` は `Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const UsageGuidePage()))` を返す（画面が閉じられると完了）。

## 4. 内部状態（フィールド・状態遷移）

なし。

## 5. 処理詳細（メソッドごとの手順・分岐・呼び出す Repository/SDK）

### ウィジェット構成

```
Scaffold
├─ AppBar(title: '使い方ガイド')
└─ SingleChildScrollView(padding: 16)
   └─ UsageGuideView()
```

`MapScreen` の AppBar の `IconButton(Icons.help_outline, tooltip: '使い方')` が `UsageGuidePage.open(context)` を呼ぶ。

## 6. データ仕様（読み書きする Firestore/Storage のパス・フィールド、定数値）

なし（`usage_guide_shown` は読み書きしない）。

## 7. 例外・エラー処理（例外の扱い・戻り値・表示メッセージ）

なし。

## 8. テスト観点（既存テストが確認していること / 未テストの観点）

既存（`test/ui/info/usage_guide_page_test.dart`）:

- タイトル「使い方ガイド」と `UsageGuideView.sections` の全見出しを表示する。
- 「自分の投稿を見る・編集する」と「プロフィールボタン」を含む説明を表示する。

未テスト: `open` による遷移。

## 9. 備考・既知の課題

なし。
