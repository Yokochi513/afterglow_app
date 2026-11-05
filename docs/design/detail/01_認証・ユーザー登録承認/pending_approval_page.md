# lib/ui/auth/pending_approval_page.dart

| 項目 | 内容 |
|---|---|
| ファイル | `lib/ui/auth/pending_approval_page.dart` |
| 基本設計 | [01 認証・ユーザー登録承認](../../01_認証・ユーザー登録承認.md) の「2. 画面・コンポーネント構成」「AuthGate の切り替え条件」 |
| 関連する基本設計 | なし |
| レイヤ | View |
| 主な依存先 | `lib/data/repositories/auth_repository.dart`、`package:provider` |
| 主な利用元 | `lib/ui/auth/auth_gate.dart` |
| テスト | なし |

## 1. 責務

ログイン済みだが管理者の承認が済んでいない（または `users/{uid}` が無い）ユーザーに、承認待ちであることを案内し、ログアウト手段を提供する。

承認されたときの画面切り替えは `AuthGate` が `users/{uid}.approved` の変化を検知して行い、本画面は承認状態を監視しない。

## 2. 構成要素（クラス・関数・定数の一覧）

| 種別 | 名前 | 概要 |
|---|---|---|
| クラス | `PendingApprovalPage`（`StatelessWidget`） | 承認待ち画面 |

## 3. 公開インターフェース（コンストラクタ引数・プロパティ・メソッドのシグネチャと説明）

```dart
const PendingApprovalPage({super.key, required this.email});
```

| プロパティ | 型 | 説明 |
|---|---|---|
| `email` | `String` | 案内文に表示する登録メールアドレス。`AuthGate` が `user.email ?? ''` を渡す |

## 4. 内部状態（フィールド・状態遷移）

`StatelessWidget` のため状態を持たない（`email` のみ）。

## 5. 処理詳細（メソッドごとの手順・分岐・呼び出す Repository/SDK）

### ウィジェット構成（`build`）

```
Scaffold
├─ AppBar
│  ├─ title: '承認待ち'
│  └─ actions: IconButton(Icons.logout, tooltip 'ログアウト')
└─ Center
   └─ Padding(32)
      └─ Column(mainAxisSize: min)
         ├─ Icon(Icons.hourglass_top, size 64, Colors.deepPurple)
         ├─ SizedBox(24)
         ├─ Text '管理者の承認待ちです'（titleLarge, 中央寄せ）
         ├─ SizedBox(12)
         ├─ Text '$email で登録しました。\n管理者が承認すると自動的にご利用いただけます。'（bodyMedium, 中央寄せ）
         ├─ SizedBox(32)
         └─ OutlinedButton.icon(Icons.logout, 'ログアウト')
```

### ログアウト（AppBar の IconButton / 本文の OutlinedButton 共通）

`context.read<AuthRepository>().signOut()` を呼ぶ（`await` しない）。`authStateChanges` が `null` を流し、`AuthGate` が `LoginPage` に切り替える。

## 6. データ仕様（読み書きする Firestore/Storage のパス・フィールド、定数値）

Firestore/Storage にはアクセスしない。Firebase Auth のログアウトのみ。

## 7. 例外・エラー処理（例外の扱い・戻り値・表示メッセージ）

`signOut` の例外は捕捉しない（`Future` を待たないため、失敗時は未処理の非同期エラーになる）。

## 8. テスト観点（既存テストが確認していること / 未テストの観点）

既存テスト: なし。

未テストの観点:

- 渡したメールアドレスが案内文に表示されること。
- 2 つのログアウトボタンが `signOut` を呼ぶこと。

## 9. 備考・既知の課題

- `email` が空文字（Auth の `email` が `null`）の場合、案内文が「 で登録しました。」となる。
- `users/{uid}` の作成に失敗したユーザーや却下処理の途中のユーザーも本画面に留まり、状況の違いを表示で区別できない。
