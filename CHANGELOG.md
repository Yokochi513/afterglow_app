# 変更履歴（Changelog）

このプロジェクトのすべての重要な変更をこのファイルに記録する。

フォーマットは [Keep a Changelog](https://keepachangelog.com/ja/1.1.0/) に準拠し、
バージョニングは [pubspec.yaml](pubspec.yaml) の `version`（`メジャー.マイナー.パッチ+ビルド番号`）と一致させる。

変更は次のカテゴリーで分類する: **Added**（追加）/ **Changed**（変更）/
**Deprecated**（非推奨）/ **Removed**（削除）/ **Fixed**（修正）/ **Security**（セキュリティ）。

## [Unreleased]

### Added

- `Post` モデルに拡張フィールドを追加（`tags` / `locationName` / `likeCount` / `updatedAt`）。

## [1.0.0+1] - 2026-06-26

フェーズ 1（単一メールドメインのクローズド運用）初回リリース。

### Added

- 地図（OpenStreetMap / `flutter_map`）上に写真付き投稿をピン留めする基本機能。
- 投稿の追加・編集・削除機能、および投稿者情報の表示。
- ユーザープロフィールページ（プロフィール画像のローディング表示を含む）。
- 管理者のメール承認を経て新規登録を有効化する認証フロー（Cloud Functions の承認通知）。
- GitHub Pages への Web デモ公開ワークフロー（CI）。

### Security

- Firestore / Storage のセキュリティルールで承認済みユーザーのみを許可。

[Unreleased]: https://github.com/Yokochi513/afterglow_app/compare/v1.0...HEAD
[1.0.0+1]: https://github.com/Yokochi513/afterglow_app/releases/tag/v1.0
