# Firestore セキュリティルールのテスト

`firestore.rules` を Firestore エミュレータ上で実際に評価する回帰テスト。

Dart 側のテストは `fake_cloud_firestore` を使っておりルールを一切評価しないため、
「クライアントの書き込みがルールで拒否される」類の不具合は検出できない。
実際に Issue #62（他人の投稿にいいねすると `likeCount` の更新が拒否され、
トランザクションごと失敗する）はそれで見逃されていた。

## 実行

Java（エミュレータの実行に必要）と firebase CLI が要る。

```bash
npm --prefix test/rules ci      # 初回・依存更新時
npm --prefix test/rules test
```

`firebase emulators:exec` がエミュレータを起動 → `node --test` を実行 → 停止まで行う。
プロジェクト ID は `demo-afterglow`（`demo-` 始まりなので実プロジェクトには接続しない）。

## 構成

- `helpers.mjs` — エミュレータ接続と、ルールを無効化して前提データを書く `seed()`
- `posts.test.mjs` — `posts` とそのサブコレクション（comments / reactions）のルール

## 書くときの方針

「許可されること」だけでなく「拒否されること」も必ず書く。ルールを緩めた箇所は、
緩めた範囲がそれ以上に広がっていないことをテストで固定する
（例: `likeCount` の ±1 だけ許可 → 他フィールドの同時更新や ±1 を超える増減が
拒否されることを確認する）。
