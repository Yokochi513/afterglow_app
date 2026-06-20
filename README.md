# Afterglow

地図上に写真付き投稿をピン留めできる Flutter アプリです。OpenStreetMap の地図上で場所を選び、写真とコメントを投稿できます。

## 公開ページ

GitHub Pages で Web 版を公開しています。

- https://yokochi513.github.io/afterglow_app/

## 主な機能

- OpenStreetMap を使った地図表示
- 地図タップ位置への投稿作成
- 画像付き投稿のアップロード
- Firestore による投稿のリアルタイム購読
- Firebase Authentication を使ったログイン導線
- Firebase Storage による投稿画像の保存

## 技術構成

- Flutter
- Firebase
  - Authentication
  - Cloud Firestore
  - Firebase Storage
- OpenStreetMap
- flutter_map

## ローカル実行

```bash
flutter pub get
flutter run -d chrome
```

モバイルエミュレータで実行する場合:

```bash
flutter run
```

## テスト

```bash
flutter test
```

テストでは `fake_cloud_firestore` と `firebase_storage_mocks` を使用しているため、ネットワーク接続なしで実行できます。

## デプロイ

`main` ブランチに push すると、GitHub Actions で Web ビルドを作成し、GitHub Pages へ自動デプロイします。

手動実行も GitHub Actions の `Deploy demo to GitHub Pages` ワークフローから可能です。

ビルド時は GitHub Pages のサブパスに合わせて、次の `base-href` を指定しています。

```bash
flutter build web --release --base-href "/afterglow_app/"
```

## ディレクトリ構成

```text
lib/
  main.dart
  firebase_options.dart
  models/
  pages/
  services/
  widgets/
test/
  services/
.github/
  workflows/
```
