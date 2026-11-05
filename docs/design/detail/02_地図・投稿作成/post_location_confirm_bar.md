# lib/ui/map/widgets/post_location_confirm_bar.dart

| 項目 | 内容 |
|---|---|
| ファイル | `lib/ui/map/widgets/post_location_confirm_bar.dart` |
| 基本設計 | [02 地図・投稿作成](../../02_地図・投稿作成.md) の 2.1 MapScreen（確認バー）/ 3.1 投稿位置の選択 |
| 関連する基本設計 | [03 フィード・投稿詳細](../../03_フィード・投稿詳細.md) の 3.2 編集（`LocationPickerPage` 経由で位置変更に流用） |
| レイヤ | View（部品） |
| 主な依存先 | `package:flutter/material.dart` のみ |
| 主な利用元 | `lib/ui/map/map_screen.dart`、`lib/ui/map/location_picker_page.dart` |
| テスト | `test/ui/map/post_location_confirm_bar_test.dart` |

## 1. 責務

地図で選んだ位置の確認バー（Issue #36）。案内文と「キャンセル」「確定」ボタンを出し、押下を呼び出し側のコールバックへ通知する。状態は持たず、位置の取り直し（地図の再タップ）や確定後の処理は呼び出し側が扱う。文言とアイコンを差し替えられ、位置の編集（Issue #37）でも使い回す。

## 2. 構成要素

| 名前 | 種別 | 公開 | 概要 |
|---|---|---|---|
| `PostLocationConfirmBar` | `StatelessWidget` | 公開 | 確認バー |

## 3. 公開インターフェース

```dart
const PostLocationConfirmBar({
  super.key,
  required VoidCallback onConfirm,
  required VoidCallback onCancel,
  String message = 'この場所に投稿しますか？',
  String confirmLabel = 'ここに投稿',
  IconData confirmIcon = Icons.add_a_photo,
})
```

| 引数 | 型 | 既定値 | 説明 |
|---|---|---|---|
| `onConfirm` | `VoidCallback` | 必須 | 確定ボタン押下時 |
| `onCancel` | `VoidCallback` | 必須 | 「キャンセル」押下時 |
| `message` | `String` | `'この場所に投稿しますか？'` | 1 行目の案内文 |
| `confirmLabel` | `String` | `'ここに投稿'` | 確定ボタンのラベル |
| `confirmIcon` | `IconData` | `Icons.add_a_photo` | 確定ボタンのアイコン |

利用元ごとの指定:

| 利用元 | message | confirmLabel | confirmIcon |
|---|---|---|---|
| `MapScreen` | 既定 | 既定 | 既定 |
| `LocationPickerPage` | `'この場所に変更しますか？'` | `'この場所にする'` | `Icons.check` |

## 4. 内部状態

なし（`StatelessWidget`）。表示・非表示は呼び出し側が `Scaffold.bottomSheet` に渡すか null にするかで切り替える。

## 5. 処理詳細

### 5.1 `build`

```
Material(elevation: 8, color: colorScheme.surface)
└ SafeArea(top: false)
  └ Padding(fromLTRB(16, 12, 16, 12))
    └ Column(mainAxisSize: min, crossAxisAlignment: start)
      ├ Text(message)
      ├ SizedBox(height: 2)
      ├ Text('地図をタップすると位置を選び直せます', style: textTheme.bodySmall)
      ├ SizedBox(height: 8)
      └ Row(mainAxisAlignment: end)
        ├ TextButton(onPressed: onCancel, child: Text('キャンセル'))
        ├ SizedBox(width: 8)
        └ FilledButton.icon(onPressed: onConfirm, icon: Icon(confirmIcon), label: Text(confirmLabel))
```

- `SafeArea(top: false)` で下端のシステム領域（ホームインジケータ等）を避ける。
- 補足文「地図をタップすると位置を選び直せます」は固定で、差し替えできない。

### 5.2 イベント

| 操作 | 処理 |
|---|---|
| 「キャンセル」タップ | `onCancel()` |
| 確定ボタンタップ | `onConfirm()` |

## 6. データ仕様

なし。

## 7. 例外・エラー処理

なし。

## 8. テスト観点

既存テスト（`post_location_confirm_bar_test.dart`）:

- 既定の案内文と操作ボタン（「キャンセル」「ここに投稿」）を表示する。
- 「ここに投稿」押下で `onConfirm` だけが呼ばれる。
- 「キャンセル」押下で `onCancel` だけが呼ばれる。
- `message` / `confirmLabel` / `confirmIcon` を差し替えられる。

未テストの観点: なし（表示専用の部品で、主要な分岐は網羅済み）。

## 9. 備考・既知の課題

- クラス名・ファイル名は「Post」を冠するが、位置編集（`LocationPickerPage`）でも使う汎用の確認バーになっている。
- 確定ボタンに送信中の無効化は無い。`MapScreen` では `showDialog` の表示中はバーが背面になるため二重押下は実質起きない。
