# lib/ui/info/widgets/release_note_view.dart

| 項目 | 内容 |
|---|---|
| ファイル | `lib/ui/info/widgets/release_note_view.dart` |
| 基本設計 | [10 お知らせ・使い方ガイド・フィードバック](../../10_お知らせ・使い方ガイド.md) の「2. 画面・コンポーネント構成」（ReleaseNoteView） |
| 関連する基本設計 | なし |
| レイヤ | View（機能内部品） |
| 主な依存先 | `lib/data/models/release_note.dart` |
| 主な利用元 | `lib/ui/info/release_notes_page.dart`, `lib/ui/info/widgets/release_note_dialog.dart` |
| テスト | なし |

## 1. 責務

1 バージョン分のリリースノート本文（カテゴリー別の変更項目一覧）を描画する。ダイアログと一覧画面で共用し、バージョン見出しは含めない。カテゴリー名（英語）を日本語ラベルとアイコンに対応付ける。

## 2. 構成要素（クラス・関数・定数の一覧）

| 名前 | 種別 | 概要 |
|---|---|---|
| `releaseNoteCategoryLabel(String)` | トップレベル関数（公開） | カテゴリーの日本語ラベル |
| `releaseNoteCategoryIcon(String)` | トップレベル関数（公開） | カテゴリーのアイコン |
| `ReleaseNoteView` | `StatelessWidget`（公開） | 本文 |

## 3. 公開インターフェース（コンストラクタ引数・プロパティ・メソッドのシグネチャと説明）

```dart
String releaseNoteCategoryLabel(String category)
IconData releaseNoteCategoryIcon(String category)
const ReleaseNoteView({super.key, required ReleaseNote releaseNote})
```

## 4. 内部状態（フィールド・状態遷移）

なし。

## 5. 処理詳細（メソッドごとの手順・分岐・呼び出す Repository/SDK）

### カテゴリーの対応

`category.toLowerCase()` で判定する（大文字小文字を区別しない）。

| カテゴリー | ラベル | アイコン |
|---|---|---|
| `added` | 新機能 | `Icons.add_circle_outline` |
| `changed` | 変更 | `Icons.tune` |
| `deprecated` | 非推奨 | `Icons.schedule` |
| `removed` | 削除 | `Icons.remove_circle_outline` |
| `fixed` | 修正 | `Icons.build_outlined` |
| `security` | セキュリティ | `Icons.shield_outlined` |
| その他 | 原文のまま | `Icons.circle_outlined` |

### ウィジェット構成

```
Column(start, min)
└─ releaseNote.sections の各 section
   └─ Padding(bottom: 12) → Column(start, min)
      ├─ Row
      │  ├─ Icon(releaseNoteCategoryIcon, size 18, primary 色)
      │  ├─ SizedBox(6)
      │  └─ Text(releaseNoteCategoryLabel, titleSmall・primary 色・太字)
      ├─ SizedBox(4)
      └─ section.items の各 item
         └─ Padding(left: 24, top: 2) → Row(start)
            ├─ Text('・')
            └─ Expanded(Text(item, bodyMedium))
```

セクション・項目は `ReleaseNote` の順序のまま表示する。

## 6. データ仕様（読み書きする Firestore/Storage のパス・フィールド、定数値）

なし。

## 7. 例外・エラー処理（例外の扱い・戻り値・表示メッセージ）

なし。`sections` が空なら何も描画しない（高さ 0 の `Column`）。

## 8. テスト観点（既存テストが確認していること / 未テストの観点）

既存テストは無い。

未テストの観点: カテゴリーのラベル・アイコン対応（未知カテゴリーの原文表示を含む）、項目の表示。

## 9. 備考・既知の課題

- 項目内の Markdown 記法（バッククォート等）はそのまま文字として表示される。
