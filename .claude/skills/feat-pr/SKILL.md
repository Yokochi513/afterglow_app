---
name: feat-pr
description: "When asked to develop a feature, branch a feature branch off the CURRENT branch, implement it, then commit, push, and open a PR back to that branch. ONLY use when user explicitly invokes /feat-pr. Do NOT trigger on general coding requests."
---

# Feature Branch → PR

機能開発の依頼を受けたら、現在のブランチから機能ブランチを切り、実装してPR作成まで一気に行う。

## General Rules
- PRの**マージ先（base）は開始時点の現在ブランチ**。`main` ではない点に注意（最初に必ず控える）。
- コミットメッセージ・PRは原則**日本語**（リポジトリの慣習）。ユーザーが言語を指定した場合はそれに従う。
- リモートは `origin`（GitHub）を使う。`gh` で操作する。
- 既存の作業ツリーがdirtyな場合は止めて、ユーザーに退避（stash/commit）を確認する。

## Workflow

### 1. 開始ブランチとクリーン状態を確認

```bash
git branch --show-current   # = BASE（PRのマージ先）として記憶する
git status --porcelain      # 出力があればdirty → 退避をユーザーに確認して停止
```

### 2. 最新化して機能ブランチを作成

```bash
git pull --ff-only origin <BASE>   # 取得できない/失敗時はスキップして続行可
git switch -c <branch-name>
```

ブランチ命名：依頼内容を表す英語の**kebab-case**。種別の接頭辞を付ける。
- 例: `feat-user-search`, `fix-login-crash`, `refactor-post-list`
- 接頭辞: feat / fix / refactor / docs / chore など

### 3. 機能を実装

通常どおりコードを編集する。完了後、ビルド/テスト/lintが利用可能なら実行して壊れていないことを確認する（Flutter: `flutter analyze` / `flutter test` 等）。

### 4. コミット

Conventional Commits（subjectは日本語可）。論理単位ごとに分けてもよい。

```bash
git add -A
git commit -m "feat: ユーザー検索機能を追加" -m "<必要なら本文（何を/なぜ）>"
```

- Subject: 命令形・簡潔・末尾ピリオドなし
- Body: 小さな差分なら省略可

### 5. プッシュ

```bash
git push -u origin <branch-name>
```

### 6. PR作成

baseは**手順1で控えた開始ブランチ**。タイトル/本文は日本語。

```bash
gh pr create --base <BASE> --head <branch-name> \
  --title "feat: ユーザー検索機能を追加" \
  --body "$(cat <<'EOF'
## 概要
<何を実装したか>

## 変更点
- <主な変更>

## 確認
- [ ] analyze / test 実行済み
EOF
)"
```

作成後、PRのURLをユーザーに提示する。

## Notes
- ユーザーが「mainにPR」など明示した場合は base をそれに変更する。
- ドラフトにしたい場合は `--draft` を付ける。
- `gh` 未認証エラー時は、ユーザーに `! gh auth login` の実行を案内する。
