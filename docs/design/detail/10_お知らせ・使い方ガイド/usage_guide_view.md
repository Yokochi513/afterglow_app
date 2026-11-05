# lib/ui/info/widgets/usage_guide_view.dart

| 項目 | 内容 |
|---|---|
| ファイル | `lib/ui/info/widgets/usage_guide_view.dart` |
| 基本設計 | [10 お知らせ・使い方ガイド・フィードバック](../../10_お知らせ・使い方ガイド.md) の「2. 画面・コンポーネント構成」（UsageGuideDialog / UsageGuidePage） |
| 関連する基本設計 | なし |
| レイヤ | View（機能内部品） |
| 主な依存先 | `package:flutter/material.dart` のみ |
| 主な利用元 | `lib/ui/info/usage_guide_page.dart`, `lib/ui/info/widgets/usage_guide_dialog.dart` |
| テスト | `test/ui/info/usage_guide_page_test.dart` |

## 1. 責務

使い方ガイドの本文。項目（アイコン・見出し・説明）を静的定数として持ち、初回起動のダイアログと読み返し用ページで同じ内容を描画する。

## 2. 構成要素（クラス・関数・定数の一覧）

| 名前 | 種別 | 概要 |
|---|---|---|
| `UsageGuideSection` | class（公開・const） | 1 項目分のデータ（`icon`・`title`・`description`） |
| `UsageGuideView` | `StatelessWidget`（公開） | 本文 |
| `UsageGuideView.sections` | `static const List<UsageGuideSection>` | ガイドの項目 |
| `_UsageGuideEntry` | `StatelessWidget` | 1 項目の見た目 |

## 3. 公開インターフェース（コンストラクタ引数・プロパティ・メソッドのシグネチャと説明）

```dart
const UsageGuideSection({
  required IconData icon,
  required String title,
  required String description,
})

const UsageGuideView({super.key})
static const List<UsageGuideSection> sections
```

`sections` はテストからも参照される（全見出しの表示確認）。

## 4. 内部状態（フィールド・状態遷移）

なし。

## 5. 処理詳細（メソッドごとの手順・分岐・呼び出す Repository/SDK）

### ウィジェット構成

```
Column(start, min)
├─ sections の各 section
│  ├─ _UsageGuideEntry
│  │  └─ Row(start)
│  │     ├─ Icon(section.icon, primary 色)
│  │     ├─ SizedBox(12)
│  │     └─ Expanded(Column(start))
│  │        ├─ Text(title, titleSmall・太字)
│  │        ├─ SizedBox(4)
│  │        └─ Text(description, bodyMedium)
│  └─ SizedBox(20)
└─ Text('このガイドは、地図画面の右上にある「使い方」ボタンからいつでも開けます。', bodySmall・outline 色)
```

スクロールは親（ダイアログ / ページの `SingleChildScrollView`）が担う。

## 6. データ仕様（読み書きする Firestore/Storage のパス・フィールド、定数値）

`sections` の内容（表示順）:

| # | アイコン | 見出し | 説明 |
|---|---|---|---|
| 1 | `Icons.map_outlined` | 地図から投稿する | 地図の好きな場所をタップすると、画面下に「ここに投稿」の確認バーが出ます。写真とコメントを添えて投稿すると、その場所にピンが立ちます。位置情報付きの写真を選ぶと、撮影場所に投稿するか提案されます（Android では端末の仕様により提案されないことがあります）。 |
| 2 | `Icons.account_circle` | 自分の投稿を見る・編集する | 画面右上のプロフィールボタン（人型のアイコン）を押すと、自分が投稿した写真が一覧で並びます。写真をタップすると投稿の詳細が開き、鉛筆アイコンで編集、ゴミ箱アイコンで削除できます。編集中は写真の並び替えや「サムネイルに設定」で、一覧に表示される1枚目を選び直せます。 |
| 3 | `Icons.dynamic_feed_outlined` | みんなの投稿を見る | 地図のピンをタップすると、その投稿の要約が開きます。画面下の「Feed」タブでは、みんなの投稿を新しい順に読めます。 |
| 4 | `Icons.favorite_border` | いいね・コメント | 投稿には「いいね」とコメントを付けられます。自分のコメントはあとから編集・削除できます。 |
| 5 | `Icons.photo_album_outlined` | アルバムとイベント | 「Album」タブでは複数の投稿をひとつのアルバムにまとめられます。「Event」タブではみんなで集まる予定を共有できます。 |
| 6 | `Icons.campaign_outlined` | お知らせとフィードバック | 画面右上のスピーカーアイコンから、アプリの更新内容を確認できます。ご意見・ご要望はその左のフィードバックボタンから送れます。 |

「自分の投稿を見る」は Issue #47 の主目的のため 2 番目に置く。

## 7. 例外・エラー処理（例外の扱い・戻り値・表示メッセージ）

なし。

## 8. テスト観点（既存テストが確認していること / 未テストの観点）

既存（`test/ui/info/usage_guide_page_test.dart`）:

- ページ・ダイアログの両方で `sections` の全見出しを表示する。
- 「自分の投稿を見る・編集する」とプロフィールボタンの案内を表示する。

未テストの観点は特に無い（文言は静的定数）。

## 9. 備考・既知の課題

- ガイドに「Contest」タブ（コンテスト機能）と通知ベルの説明が無い。
- 文言は画面上の配置（右上ボタンの並び・タブ名）に依存するため、`MapScreen` の AppBar やタブ構成を変えたら合わせて更新が要る。
