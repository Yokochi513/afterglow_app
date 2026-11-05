# lib/ui/auth/login_page.dart

| 項目 | 内容 |
|---|---|
| ファイル | `lib/ui/auth/login_page.dart` |
| 基本設計 | [01 認証・ユーザー登録承認](../../01_認証・ユーザー登録承認.md) の「3.2 ログイン・ログアウト」「6. 入力チェック・エラー処理」 |
| 関連する基本設計 | なし |
| レイヤ | View（ViewModel なし） |
| 主な依存先 | `lib/data/repositories/auth_repository.dart`, `lib/ui/auth/register_page.dart`、`package:provider`、`package:firebase_auth`（`FirebaseAuthException`） |
| 主な利用元 | `lib/ui/auth/auth_gate.dart`（未ログイン時に表示）, `lib/ui/auth/register_page.dart`（トップレベル関数 `validateEmail` / `validatePassword` / `authErrorMessage` を利用） |
| テスト | なし |

## 1. 責務

- メールアドレス・パスワードのフォームを表示し、検証後に `AuthRepository.signIn` を呼ぶ。
- 新規登録画面（`RegisterPage`）への導線を出す。
- 認証系で共有する入力検証関数と、`FirebaseAuthException` の日本語メッセージ変換関数をトップレベルに定義する（`RegisterPage` も使う）。

ログイン成功後の画面切り替えは `AuthGate` が行い、本画面は遷移処理を持たない。

## 2. 構成要素（クラス・関数・定数の一覧）

| 種別 | 名前 | 概要 |
|---|---|---|
| クラス | `LoginPage`（`StatefulWidget`） | ログイン画面 |
| クラス | `_LoginPageState` | フォーム状態と送信処理 |
| 関数 | `String? validateEmail(String? value)` | メールアドレス検証（公開） |
| 関数 | `String? validatePassword(String? value)` | パスワード検証（公開） |
| 関数 | `String authErrorMessage(FirebaseAuthException e)` | エラーコード → 日本語（公開） |

## 3. 公開インターフェース（コンストラクタ引数・プロパティ・メソッドのシグネチャと説明）

```dart
const LoginPage({super.key});
```

| 関数 | 戻り値 |
|---|---|
| `validateEmail(value)` | `trim` 後が空 →「メールアドレスを入力してください」、正規表現 `^[\w.+-]+@[\w-]+\.[\w.-]+$` 不一致 →「メールアドレスの形式が正しくありません」、それ以外 `null` |
| `validatePassword(value)` | 空 →「パスワードを入力してください」、8 文字未満 →「パスワードは8文字以上で入力してください」、それ以外 `null`（`trim` しない） |
| `authErrorMessage(e)` | 下表 |

| `e.code` | メッセージ |
|---|---|
| `invalid-email` | メールアドレスの形式が正しくありません |
| `user-disabled` | このアカウントは無効化されています |
| `user-not-found` / `wrong-password` / `invalid-credential` | メールアドレスまたはパスワードが正しくありません |
| `email-already-in-use` | このメールアドレスは既に登録されています |
| `weak-password` | パスワードが脆弱です。より複雑なものを設定してください |
| `too-many-requests` | 試行回数が多すぎます。しばらくしてから再度お試しください |
| その他 | `認証に失敗しました（${e.code}）` |

## 4. 内部状態（フィールド・状態遷移）

`_LoginPageState` のフィールド:

| フィールド | 型 | 初期値 | 説明 |
|---|---|---|---|
| `_formKey` | `GlobalKey<FormState>` | 新規 | フォーム検証 |
| `_emailController` | `TextEditingController` | 新規 | メール入力 |
| `_passwordController` | `TextEditingController` | 新規 | パスワード入力 |
| `_authRepository` | `AuthRepository`（`late final`） | `context.read<AuthRepository>()`（初回アクセス時に評価） | |
| `_isSubmitting` | `bool` | `false` | 送信中フラグ |

状態遷移: `_isSubmitting` が `false →（送信開始）true →（完了・失敗）false`。

## 5. 処理詳細（メソッドごとの手順・分岐・呼び出す Repository/SDK）

### ライフサイクル

- `initState`: オーバーライドなし。
- `dispose`: `_emailController`・`_passwordController` を `dispose` する。

### ウィジェット構成（`build`）

```
Scaffold
├─ AppBar(title: 'ログイン')
└─ Center
   └─ SingleChildScrollView(padding: 24)
      └─ ConstrainedBox(maxWidth: 420)
         └─ Form(key: _formKey)
            └─ Column(stretch)
               ├─ TextFormField  label 'メールアドレス', keyboardType: emailAddress, validator: validateEmail
               ├─ SizedBox(16)
               ├─ TextFormField  label 'パスワード', obscureText: true, validator: validatePassword
               ├─ SizedBox(24)
               ├─ ElevatedButton  送信中は無効＋20×20 のスピナー（strokeWidth 2）/ 通常は 'ログイン'
               ├─ SizedBox(12)
               └─ TextButton 'アカウントをお持ちでない方はこちら（新規登録）'（送信中は無効）
```

入力欄はいずれも `OutlineInputBorder`。

### `_submit()`（ログインボタン）

1. `_formKey.currentState!.validate()` が `false` なら終了。
2. `ScaffoldMessenger.of(context)` を先に取得する（非同期後に `context` を使わないため）。
3. `setState(() => _isSubmitting = true)`。
4. `_authRepository.signIn(_emailController.text.trim(), _passwordController.text)` を待つ。
   - 成功時は何もしない（`AuthGate` が切り替える）。
5. `FirebaseAuthException` → 赤背景 SnackBar に `authErrorMessage(e)`。
6. その他の例外 → 赤背景 SnackBar「ログインに失敗しました」。
7. `finally`: `mounted` なら `_isSubmitting = false`（成功時は `AuthGate` により本画面が破棄されているため `mounted` が `false` になりうる）。

### 新規登録ボタン

`Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const RegisterPage()))`。

## 6. データ仕様（読み書きする Firestore/Storage のパス・フィールド、定数値）

Firestore/Storage には直接アクセスしない。Firebase Auth のログインのみ（`AuthRepository.signIn` 経由）。

| 定数 | 値 |
|---|---|
| メール正規表現 | `^[\w.+-]+@[\w-]+\.[\w.-]+$` |
| パスワード最小長 | 8 文字 |
| フォーム最大幅 | 420 |

## 7. 例外・エラー処理（例外の扱い・戻り値・表示メッセージ）

| 状況 | 表示 |
|---|---|
| 入力検証エラー | 各入力欄の下にバリデータのメッセージ |
| `FirebaseAuthException` | 赤 SnackBar（`authErrorMessage` の文言） |
| その他の例外 | 赤 SnackBar「ログインに失敗しました」 |

## 8. テスト観点（既存テストが確認していること / 未テストの観点）

既存テスト: なし。

未テストの観点:

- `validateEmail` / `validatePassword` / `authErrorMessage` の各分岐（純粋関数で単体テストしやすい）。
- 送信中にボタンが無効化されスピナーが出ること。
- 認証失敗時に SnackBar が出ること。
- 新規登録ボタンで `RegisterPage` に遷移すること。

## 9. 備考・既知の課題

- ログイン時にも `validatePassword` の 8 文字以上チェックがかかる。管理者がコンソールから 8 文字未満のパスワードで作成したアカウントは UI からログインできない。
- 共有の検証関数・エラー変換が画面ファイル（`login_page.dart`）に置かれており、`RegisterPage` が `LoginPage` のファイルに依存している。
- 入力検証・送信を持つが ViewModel は無い（基本設計 00 の 3.5「ViewModel のない画面」）。
- パスワード再設定の導線は無い。
