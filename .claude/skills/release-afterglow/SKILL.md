---
name: release-afterglow
description: Prepare an Afterglow release — bump the version, finalize CHANGELOG.md, verify the web release build, and open the dev → main release PR (merging main deploys to GitHub Pages). Use when asked to cut, prepare, or ship an Afterglow release (e.g. "v1.1.0 をリリースして", "リリース PR を作って").
---

# Afterglow リリース手順

`dev` の内容を `main` へ出すためのリリース準備を行う。担当範囲は **リリース PR の作成まで**。
PR のマージ（= 本番デプロイ）とマージ後の確認は**人間が行う**（本 skill では実行しない）。

**`main` への push は本番デプロイ**（`.github/workflows/deploy.yml` が Web をビルドし
https://yokochi513.github.io/afterglow_app/ へ公開する）。`dev` → `main` のマージ = リリース = 公開なので、
壊れた状態を `main` に入れない。ブランチ運用の正典は [CLAUDE.md](../../../CLAUDE.md)。

成果物は 3 つ:

1. `CHANGELOG.md` + `pubspec.yaml` のリリース用更新（`dev` にマージ済み）
2. ローカルでの Web リリースビルド検証（`main` の CI が落ちないことの事前確認）
3. `dev` → `main` のリリース PR

## 1. 事前確認

- `git status` がクリーンで、`dev` が origin/dev と同期済みであること（`git fetch && git status`）。未コミットの変更があれば作業を止めてユーザーに確認する。
- `gh auth status` が通ること。リモートは `origin`（GitHub）を使う（`azure` は使わない）。
- 前回リリース以降の変更を把握する: `git log --oneline main..dev` と `gh pr list --state merged --base dev --limit 20`。
- `main..dev` が空なら出すものが無い。その旨を報告して終了する。

## 2. バージョン決定

`pubspec.yaml` の `version: x.y.z+N` を確認し、次バージョンを決める（semver）:

- 機能追加あり → マイナー上げ（1.0.0 → 1.1.0）
- 修正のみ → パッチ上げ（1.0.0 → 1.0.1）
- ビルド番号 `+N` は毎リリース 1 ずつ増やす（1.0.0+1 → 1.1.0+2）

**決定したバージョンは着手前にユーザーへ提示して合意を取る。** 迷ったら推測せず尋ねる。

## 3. リリース準備ブランチ

`dev` から `release-x.y.z` を切る（例 `release-1.1.0`）。バージョン更新は**まず `dev` に入れてから**
`dev` → `main` の PR を出す。この順序により `dev` が常に `main` を先行し、back-merge が不要になる。

## 4. CHANGELOG.md

`CHANGELOG.md` は Keep a Changelog 形式で、**アプリに同梱されるアセット**（`pubspec.yaml` の `assets:`）。
`lib/services/release_note_service.dart` が実行時にパースし、更新後の初回起動でお知らせとして表示する。
つまりこのファイルの文面と見出しは**そのまま利用者が読む UI**であり、書式ミスは表示バグになる。

- `## [Unreleased]` を `## [X.Y.Z+N] - YYYY-MM-DD` にリネームする。
  - **見出しのバージョンはビルド番号込み**（`1.0.0+1` 形式）。`ReleaseNoteService.currentVersion()` が
    `version+buildNumber` で突き合わせるため、`pubspec.yaml` の `version:` と**完全一致**していないと
    自動お知らせが該当バージョンを見つけられない。日付は today。
  - 見出し書式は `## [<version>] - <date>`（`ReleaseNote._parseVersionHeader` の正規表現に一致させる）。
- その上に**新しい空の `## [Unreleased]`** を追加する。
- 変更項目は `### Added` / `### Changed` / `### Deprecated` / `### Removed` / `### Fixed` / `### Security`
  のいずれかの見出し配下に置く。**カテゴリー見出しの外に書いた項目はパーサに無視され、アプリに表示されない。**
- `[Unreleased]` の項目が実際のマージ内容を網羅しているか `git log --oneline main..dev` と突き合わせ、漏れを追記する。
- 文末のリンク参照行（`[Unreleased]: .../compare/vX.Y...HEAD` と `[X.Y.Z+N]: .../releases/tag/...`）も新バージョンに合わせて更新する。

書き方は既存エントリに合わせる: **利用者目線の日本語 1 行、「〜できるようになりました」「〜を追加」「〜を修正」調**。
Issue 番号や実装用語（Firestore, flutter_map など内部の仕組み）は書かない。

`pubspec.yaml` の `version:` も新バージョンに更新する。

## 5. 検証

```bash
flutter pub get
flutter analyze                                   # 警告ゼロを維持
dart format .
dart format --output=none --set-exit-if-changed .
flutter test
```

`functions/` に変更が含まれるリリースなら以下も実行する:

```bash
npm --prefix functions ci
npm --prefix functions run build                  # tsc。lint/test スクリプトは未定義
```

Flutter が出力前に固まる場合は Flutter/Dart プロセスと SDK キャッシュのロックを確認する。

## 6. Web リリースビルド検証

`main` へのマージで CI が同じビルドを実行して即公開するため、**ローカルで先に通しておく**:

```bash
flutter build web --release --base-href "/afterglow_app/"
```

- `--base-href` は公開 URL（`https://yokochi513.github.io/afterglow_app/`）に合わせる。`deploy.yml` と同一のコマンド。
- 出力 `build/web` は生成物。**コミットしない**（`git status` で確認する）。
- CHANGELOG がアセットとして `build/web/assets/` に載っていること、
  `flutter build web` がバージョン更新後の `pubspec.yaml` で成功することを確認して報告する。

## 7. コミットと dev へのマージ

コミット（変更は `CHANGELOG.md` と `pubspec.yaml` の 2 ファイルのみ）:

```
chore: リリース vX.Y.Z 準備（バージョン更新・CHANGELOG 記載）

pubspec.yaml を A.B.C+N → X.Y.Z+M に更新し、CHANGELOG の [Unreleased] を
[X.Y.Z+M] - YYYY-MM-DD にリネーム。<主な変更の要約>

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>
```

push 後、`gh pr create --base dev --head release-x.y.z --title "chore: リリース vX.Y.Z 準備"` で
準備 PR を作る。**この PR のマージは人間に任せる**（マージ後に次の手順へ進む）。

## 8. リリース PR（dev → main）

準備 PR が `dev` にマージされたら、`gh pr create --base main --head dev --title "release: vX.Y.Z"` を作る。
本文の構成:

```markdown
## 概要
dev → main のリリース PR（vX.Y.Z）。前回リリース `A.B.C` 以降の新機能・修正をまとめて本番へ反映する。

- `pubspec.yaml`: `A.B.C+N` → `X.Y.Z+M`
- `CHANGELOG.md`: `[Unreleased]` → `[X.Y.Z+M] - YYYY-MM-DD` にリネームし、新しい空の `[Unreleased]` を追加

**このマージで本番公開される**: `main` への push を検知して `deploy.yml` が Web をビルドし
GitHub Pages（https://yokochi513.github.io/afterglow_app/ ）へデプロイする。

## 含まれる変更（A.B.C 以降）
- <変更の要約> (#issue)

## リリースノート（利用者向け / CHANGELOG [X.Y.Z+M]）
- <CHANGELOG の該当セクションをそのまま転記。アプリ内お知らせに表示される文面>

## 検証
- [x] `flutter analyze`（警告ゼロ）
- [x] `flutter test`
- [x] `flutter build web --release --base-href "/afterglow_app/"`
- [ ] マージ後、Pages のデプロイ成功と公開サイトの表示を確認
- [ ] マージ後、更新後初回起動でリリースお知らせが `X.Y.Z+M` の内容を表示することを確認

🤖 Generated with [Claude Code](https://claude.com/claude-code)
```

`Closes #<番号>` はこの PR に書かない。Issue は `close-issue-on-dev-merge.yml` が
`dev` へのマージ時点で既に閉じている。

## 9. 完了報告

ユーザーに次を伝える:

- 新バージョンと 2 つの PR の URL（準備 PR / リリース PR）
- 実行した検証コマンドとその結果
- Web リリースビルドの成否
- 残っている人間の作業:
  1. 準備 PR（→ `dev`）をレビューしてマージ
  2. リリース PR（`dev` → `main`）をレビューしてマージ = **本番公開**
  3. Actions で Pages デプロイの成功と公開サイトの表示を確認
  4. リリースお知らせが新バージョンの内容で出ることを確認
  5. 必要なら `v X.Y.Z` のタグ / GitHub Release を作成し、CHANGELOG のリンク参照行と整合させる
