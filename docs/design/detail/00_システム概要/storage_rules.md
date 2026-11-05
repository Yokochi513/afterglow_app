# storage.rules

| 項目 | 内容 |
|---|---|
| ファイル | `storage.rules` |
| 基本設計 | [00 システム概要・共通設計](../../00_システム概要.md) の 5 章「Storage パス」・6 章（権限モデル）・8 章（画像サイズ） |
| 関連する基本設計 | [02 地図・投稿作成](../../02_地図・投稿作成.md)（投稿画像のアップロード）、[03 フィード・投稿詳細](../../03_フィード・投稿詳細.md)（編集・削除時の画像削除）、[09 プロフィール](../../09_プロフィール.md)（プロフィール画像） |
| レイヤ | Rules |
| 主な依存先 | なし（`rules_version = '2'`） |
| 主な利用元 | Firebase Storage（クライアントのアクセスを評価）。クライアント側の書き手は `lib/data/repositories/post_repository.dart`（`createPost` / `updatePost` / `deletePost`）と `lib/data/repositories/user_repository.dart`（`uploadProfileImage`）。デプロイは `firebase.json` の `storage.rules` と `.github/workflows/firestore-rules.yml`（`--only firestore:rules,storage`） |
| テスト | なし（`test/rules/` は Firestore のみ） |

## 1. 責務

Firebase Storage 上の画像へのクライアントアクセスを認可する。

- 読み取りはログイン済みユーザーに限る。
- 書き込みは本人のディレクトリ（パスの `{userId}` が自分の UID）配下に限り、10MB 未満の `image/*` だけを許可する。
- Storage ルールは Firestore を参照しない設計のため、承認状態（`approved`）は判定しない。投稿の作成自体は Firestore ルールで承認済みユーザーに限定される。

## 2. 構成要素（クラス・関数・定数の一覧）

| 種別 | 名前 | 定義 |
|---|---|---|
| 関数 | `isSignedIn()` | `request.auth != null` |
| 関数 | `isValidImage()` | `request.resource.size < 10 * 1024 * 1024 && request.resource.contentType.matches('image/.*')` |
| match | `/posts/{userId}/{allPaths=**}` | 投稿画像 |
| match | `/profiles/{userId}/{allPaths=**}` | プロフィール画像（コメント上は「将来のプロフィール機能用」） |

いずれも `match /b/{bucket}/o` 配下。

## 3. 公開インターフェース（コンストラクタ引数・プロパティ・メソッドのシグネチャと説明）

ルールのため該当なし。許可条件は 5 章を参照。

## 4. 内部状態（フィールド・状態遷移）

なし

## 5. 処理詳細（メソッドごとの手順・分岐・呼び出す Repository/SDK）

### `posts/{userId}/{allPaths=**}`

| 操作 | 条件 |
|---|---|
| read | `isSignedIn()` |
| write（create / update / delete） | `isSignedIn() && request.auth.uid == userId && isValidImage()` |

### `profiles/{userId}/{allPaths=**}`

| 操作 | 条件 |
|---|---|
| read | `isSignedIn()` |
| write（create / update / delete） | `isSignedIn() && request.auth.uid == userId && isValidImage()` |

上記以外のパスは一致する `match` が無いため、すべて拒否される。

クライアントの操作との対応:

| クライアント処理 | パス | 操作 |
|---|---|---|
| `PostRepository.createPost` | `posts/{post.userId}/{postId}_{index}.jpg` | `putData`（`contentType: 'image/jpeg'`, `cacheControl: 'public, max-age=31536000, immutable'`、短辺 2048px・品質 85% に圧縮済み） |
| `PostRepository.createPost`（失敗時の掃除） | 同上 | `delete` |
| `PostRepository.updatePost` | `refFromURL(削除された画像 URL)` | `delete` |
| `PostRepository.deletePost` | `posts/{authorId}/{postId}_{index}.jpg` | `delete` |
| `UserRepository.uploadProfileImage` | `profiles/{uid}/avatar.jpg` | `putData`（`contentType: 'image/jpeg'`、圧縮なし） |

## 6. データ仕様（読み書きする Firestore/Storage のパス・フィールド、定数値）

| 定数 | 値 |
|---|---|
| サイズ上限 | `10 * 1024 * 1024`（10MB、**未満**） |
| Content-Type | 正規表現 `image/.*` |

| パス | 内容 |
|---|---|
| `posts/{userId}/{postId}_{index}.jpg` | 投稿画像。`{userId}` は実投稿者の UID（匿名のコンテスト応募でも実 UID のディレクトリに置く） |
| `profiles/{uid}/avatar.jpg` | プロフィール画像 |

## 7. 例外・エラー処理（例外の扱い・戻り値・表示メッセージ）

- 拒否されるとクライアント SDK が `FirebaseException`（`unauthorized`）を投げる。
  - `createPost` はアップロードの失敗を捕捉し、アップロード済み画像を削除して `false` を返す。
  - `updatePost` / `deletePost` は Storage の削除失敗を無視し、Firestore の更新・削除が成功していれば `true` を返す。
  - `uploadProfileImage` は例外を呼び出し元へ伝播する。

## 8. テスト観点（既存テストが確認していること / 未テストの観点）

- 既存テスト: なし（Dart 側は `firebase_storage_mocks` を使うためルールを評価しない。`test/rules/` は Firestore エミュレータのみ起動する）。
- 未テスト: 未ログインの読取拒否、他人のディレクトリへの書き込み拒否、10MB 以上・画像以外の拒否、削除の可否。

## 9. 備考・既知の課題

- **削除が拒否される可能性**: `allow write` は削除も含むが、削除リクエストでは `request.resource` が存在しないため、`isValidImage()` の `request.resource.size` が評価エラーとなり、削除は拒否されると考えられる（エミュレータでは未検証）。その場合、`updatePost` / `deletePost` / `createPost` 失敗時の画像削除はいずれも失敗し、クライアントは失敗を無視するため、Storage に画像が残り続ける。削除を許可するには `allow delete: if isSignedIn() && request.auth.uid == userId;` を分けて書く必要がある。
- 管理者が他人の投稿を削除した場合も、パスの `{userId}` が管理者の UID と一致しないため画像は削除できない（上記の課題と独立に発生する）。
- 承認状態を判定しないため、未承認ユーザーでも自分のディレクトリへ画像をアップロードできる（Firestore の投稿作成は拒否されるため、参照されない画像が残り得る）。
- 読み取りもログイン済みであれば未承認ユーザーに許可される（ダウンロード URL を知っていればトークン付き URL でアクセスできる点も同様）。
- `uploadProfileImage` は画像を圧縮せず、元形式に関わらず `contentType: 'image/jpeg'` を付ける。10MB 以上の画像はルールで拒否される。
- `profiles/` のコメント「将来のプロフィール機能用」は古い（プロフィール画像のアップロードは実装済み）。
