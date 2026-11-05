# lib/app/app.dart

| 項目 | 内容 |
|---|---|
| ファイル | `lib/app/app.dart` |
| 基本設計 | [00 システム概要・共通設計](../../00_システム概要.md) の 2 章（Material 3・NotoSansJP）・3.2 節（依存の注入）・4 章（画面遷移の起点） |
| 関連する基本設計 | [01 認証・ユーザー登録承認](../../01_認証・ユーザー登録承認.md) 2 章（`AuthGate` をホームにする） |
| レイヤ | App |
| 主な依存先 | `lib/app/dependencies.dart`（`AppDependencies`, `DependencyScope`）、`lib/ui/auth/auth_gate.dart`（`AuthGate`）、`flutter/material.dart` |
| 主な利用元 | `lib/main.dart` |
| テスト | なし |

## 1. 責務

アプリのルートウィジェット `MyApp` を定義する。`DependencyScope` で依存を `MaterialApp` の外側から提供し、アプリ名・テーマ・ホーム画面（`AuthGate`）を設定する。

## 2. 構成要素（クラス・関数・定数の一覧）

| 種別 | 名前 | 概要 |
|---|---|---|
| クラス | `MyApp extends StatelessWidget` | ルートウィジェット |

## 3. 公開インターフェース（コンストラクタ引数・プロパティ・メソッドのシグネチャと説明）

| シグネチャ | 説明 |
|---|---|
| `const MyApp({super.key, required this.dependencies})` | 依存一式を受け取る |
| `final AppDependencies dependencies` | 配下へ提供する依存。本番は `main()` が `AppDependencies()` を渡す |
| `Widget build(BuildContext context)` | `DependencyScope` → `MaterialApp` を返す |

## 4. 内部状態（フィールド・状態遷移）

なし（`StatelessWidget`）。

## 5. 処理詳細（メソッドごとの手順・分岐・呼び出す Repository/SDK）

### `build`

次のツリーを返す。分岐はない。

```
DependencyScope(dependencies: dependencies)
  └ MaterialApp
      title: 'Afterglow'
      debugShowCheckedModeBanner: false
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        fontFamily: 'NotoSansJP',
      )
      home: const AuthGate()
```

- `DependencyScope` を `MaterialApp` の**外側**に置くことで、`Navigator.push` で開いた画面（`MaterialApp` の Navigator 配下）も同じ Provider からインスタンスを受け取れる。
- `ThemeData` は `useMaterial3` を明示していないが、Flutter の既定で Material 3 となる。
- フォント `NotoSansJP` は `pubspec.yaml` の `fonts`（`assets/fonts/NotoSansJP-Regular.ttf` / `NotoSansJP-Bold.ttf`）で定義される。
- ルーティングは名前付きルートを使わず、`home` の `AuthGate` が認証・承認状態に応じて `LoginPage` / `PendingApprovalPage` / `MainShell` を切り替える。

## 6. データ仕様（読み書きする Firestore/Storage のパス・フィールド、定数値）

| 定数 | 値 |
|---|---|
| アプリタイトル | `'Afterglow'` |
| テーマのシード色 | `Colors.deepPurple` |
| フォントファミリー | `'NotoSansJP'` |

Firestore / Storage へのアクセスはしない。

## 7. 例外・エラー処理（例外の扱い・戻り値・表示メッセージ）

なし

## 8. テスト観点（既存テストが確認していること / 未テストの観点）

- 既存テスト: なし。ウィジェットテストは `MyApp` を使わず、`withDependencies(AppDependencies(...), MaterialApp(...))` で同等の構成を組み立てる。
- 未テスト: テーマ設定・`AuthGate` がホームになること。

## 9. 備考・既知の課題

- ダークテーマ・ローカライズ（`localizationsDelegates` / `locale`）は設定していない。
