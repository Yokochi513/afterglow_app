# Firestore セキュリティルールのテスト

`firestore.rules` を Firestore エミュレータ上で実際に評価する回帰テスト。

Dart 側のテストは `fake_cloud_firestore` を使っておりルールを一切評価しないため、
「クライアントの書き込みがルールで拒否される」類の不具合は検出できない。
実際に Issue #62（他人の投稿にいいねすると `likeCount` の更新が拒否され、
トランザクションごと失敗する）はそれで見逃されていた。

## 実行

Java（エミュレータの実行に必要）が要る。firebase CLI は devDependencies の
`firebase-tools` を使うので、グローバルインストールは不要。

```bash
npm --prefix test/rules ci      # 初回・依存更新時
npm --prefix test/rules test
```

`firebase emulators:exec` がエミュレータを起動 → `node --test` を実行 → 停止まで行う。
プロジェクト ID は `demo-afterglow`（`demo-` 始まりなので実プロジェクトには接続しない）。

`main` への push とルール関連ファイルを含む PR では、
`.github/workflows/firestore-rules.yml` が CI 上でも同じテストを実行する。

## 構成

- `helpers.mjs` — エミュレータ接続と、ルールを無効化して前提データを書く `seed()`
- `posts.test.mjs` — `posts` とそのサブコレクション（comments / reactions）のルール
- `users.test.mjs` — `users` と、承認状態（承認済み / 未承認 / 未ログイン / 管理者）
  による読み書きの可否。通知・Functions 専用コレクションの遮断も含む

テストファイルを追加するときは、`createTestEnv('<一意な名前>')` に他と重複しない
名前を渡すこと。`node --test` はファイルを並列実行するため、プロジェクトIDを共有すると
片方の `clearFirestore()` がもう片方の前提データを消してテストが落ちる。

## 書くときの方針

「許可されること」だけでなく「拒否されること」も必ず書く。ルールを緩めた箇所は、
緩めた範囲がそれ以上に広がっていないことをテストで固定する
（例: `likeCount` の ±1 だけ許可 → 他フィールドの同時更新や ±1 を超える増減が
拒否されることを確認する）。
