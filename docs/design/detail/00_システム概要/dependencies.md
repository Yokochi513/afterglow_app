# lib/app/dependencies.dart

| 項目 | 内容 |
|---|---|
| ファイル | `lib/app/dependencies.dart` |
| 基本設計 | [00 システム概要・共通設計](../../00_システム概要.md) の 3.1 節（レイヤと責務）・3.2 節（依存の注入） |
| 関連する基本設計 | 全機能（01〜10）。各機能の Repository / Service をここで組み立てる |
| レイヤ | App |
| 主な依存先 | `lib/data/repositories/` の全 Repository（album, auth, comment, contest, event, notification, post, reaction, release_note, usage_guide, user）、`lib/data/services/` の全 Service（geocoding, image, location, push_notification）、`cloud_firestore`、`firebase_auth`、`firebase_storage`、`flutter/widgets.dart`、`provider` |
| 主な利用元 | `lib/main.dart`（`AppDependencies()`）、`lib/app/app.dart`（`DependencyScope`）、`test/helpers/dependencies.dart`（`withDependencies`）。提供したインスタンスは `lib/ui/` 配下と `lib/app/main_shell.dart` が `context.read<T>()` で受け取る（6 章の表） |
| テスト | 専用テストなし。`test/helpers/dependencies.dart` 経由で `test/ui/core/contest_entry_badge_test.dart`, `post_card_test.dart`, `reaction_bar_test.dart`, `test/ui/feed/feed_page_test.dart`, `test/ui/map/map_search_bar_test.dart`, `test/ui/notification/notification_page_test.dart`, `test/ui/post/post_add_dialog_test.dart`, `post_detail_page_test.dart`, `post_widget_test.dart` が利用 |

## 1. 責務

- `AppDependencies`: アプリが使う Repository / Service を組み立てる依存の注入元。Firebase インスタンスや個別の Repository / Service を外から差し替えられるようにし、Repository 間の依存（`PostRepository` → `ImageService`、`ContestRepository` → `PostRepository`）を解決する。
- `DependencyScope`: `AppDependencies` の各インスタンスを `MultiProvider` で配下のウィジェットへ提供する。

## 2. 構成要素（クラス・関数・定数の一覧）

| 種別 | 名前 | 概要 |
|---|---|---|
| クラス | `AppDependencies` | 依存の組み立て（遅延生成） |
| クラス | `DependencyScope extends StatelessWidget` | `MultiProvider` で 15 種類の依存を提供 |

## 3. 公開インターフェース（コンストラクタ引数・プロパティ・メソッドのシグネチャと説明）

### `AppDependencies`

```dart
AppDependencies({
  this.firestore,              // FirebaseFirestore?
  this.storage,                // FirebaseStorage?
  this.auth,                   // FirebaseAuth?
  AuthRepository? authRepository,
  UserRepository? userRepository,
  PostRepository? postRepository,
  ContestRepository? contestRepository,
  CommentRepository? commentRepository,
  ReactionRepository? reactionRepository,
  AlbumRepository? albumRepository,
  EventRepository? eventRepository,
  NotificationRepository? notificationRepository,
  ReleaseNoteRepository? releaseNoteRepository,
  UsageGuideRepository? usageGuideRepository,
  ImageService? imageService,
  LocationService? locationService,
  GeocodingService? geocodingService,
  PushNotificationService? pushNotificationService,
})
```

すべて任意引数。Repository / Service の引数は同名の private フィールド（`_authRepository` 等）に保持し、公開プロパティの初期化時に優先して使う。

| 公開プロパティ | 型 | 生成式（引数省略時） |
|---|---|---|
| `firestore` | `FirebaseFirestore?` | 引数そのまま（null なら各 Repository が `.instance`） |
| `storage` | `FirebaseStorage?` | 同上 |
| `auth` | `FirebaseAuth?` | 同上 |
| `imageService` | `ImageService`（`late final`） | `ImageService()` |
| `locationService` | `LocationService`（`late final`） | `LocationService()` |
| `geocodingService` | `GeocodingService`（`late final`） | `GeocodingService()` |
| `pushNotificationService` | `PushNotificationService`（`late final`） | `PushNotificationService(firestore: firestore)` |
| `authRepository` | `AuthRepository`（`late final`） | `AuthRepository(auth: auth, firestore: firestore)` |
| `userRepository` | `UserRepository`（`late final`） | `UserRepository(firestore: firestore, storage: storage)` |
| `postRepository` | `PostRepository`（`late final`） | `PostRepository(firestore: firestore, storage: storage, imageService: imageService)` |
| `contestRepository` | `ContestRepository`（`late final`） | `ContestRepository(firestore: firestore, postRepository: postRepository)` |
| `commentRepository` | `CommentRepository`（`late final`） | `CommentRepository(firestore: firestore)` |
| `reactionRepository` | `ReactionRepository`（`late final`） | `ReactionRepository(firestore: firestore)` |
| `albumRepository` | `AlbumRepository`（`late final`） | `AlbumRepository(firestore: firestore)` |
| `eventRepository` | `EventRepository`（`late final`） | `EventRepository(firestore: firestore)` |
| `notificationRepository` | `NotificationRepository`（`late final`） | `NotificationRepository(firestore: firestore)` |
| `releaseNoteRepository` | `ReleaseNoteRepository`（`late final`） | `ReleaseNoteRepository()` |
| `usageGuideRepository` | `UsageGuideRepository`（`late final`） | `UsageGuideRepository()` |

各プロパティは `_xxx ?? <生成式>` の形で、差し替え引数があればそれを、無ければ生成式の結果を返す。

### `DependencyScope`

| シグネチャ | 説明 |
|---|---|
| `const DependencyScope({super.key, required this.dependencies, required this.child})` | 提供する依存と子ウィジェット |
| `final AppDependencies dependencies` | 提供元 |
| `final Widget child` | 配下のツリー（アプリでは `MaterialApp`） |
| `Widget build(BuildContext context)` | `MultiProvider` を返す |

## 4. 内部状態（フィールド・状態遷移）

- `AppDependencies` の公開プロパティは `late final` のため、**初回アクセス時に 1 回だけ**生成され、以後は同じインスタンスを返す。
- 依存の連鎖で間接的に生成されるものがある:
  - `postRepository` の初回アクセスで `imageService` が生成される。
  - `contestRepository` の初回アクセスで `postRepository`（→ `imageService`）が生成される。
- 差し替え引数で `postRepository` を渡した場合でも、`contestRepository` を渡さなければ `ContestRepository` は差し替え後の `postRepository` を使う（`postRepository` プロパティ経由のため）。
- `DependencyScope` は状態を持たない。

## 5. 処理詳細（メソッドごとの手順・分岐・呼び出す Repository/SDK）

### `DependencyScope.build`

1. `final d = dependencies;`
2. 次の順で `Provider<T>(create: (_) => d.<プロパティ>)` を並べた `MultiProvider` を返す。

| 順 | 型 `T` | `create` |
|---|---|---|
| 1 | `ImageService` | `d.imageService` |
| 2 | `LocationService` | `d.locationService` |
| 3 | `GeocodingService` | `d.geocodingService` |
| 4 | `PushNotificationService` | `d.pushNotificationService` |
| 5 | `AuthRepository` | `d.authRepository` |
| 6 | `UserRepository` | `d.userRepository` |
| 7 | `PostRepository` | `d.postRepository` |
| 8 | `ContestRepository` | `d.contestRepository` |
| 9 | `CommentRepository` | `d.commentRepository` |
| 10 | `ReactionRepository` | `d.reactionRepository` |
| 11 | `AlbumRepository` | `d.albumRepository` |
| 12 | `EventRepository` | `d.eventRepository` |
| 13 | `NotificationRepository` | `d.notificationRepository` |
| 14 | `ReleaseNoteRepository` | `d.releaseNoteRepository` |
| 15 | `UsageGuideRepository` | `d.usageGuideRepository` |

- `Provider` の `create` は遅延評価のため、どのウィジェットからも `read` されない依存は生成されない（`late final` と二重に遅延される）。
- `dispose` は指定しない。Repository / Service は破棄処理を持たない前提。

## 6. データ仕様（読み書きする Firestore/Storage のパス・フィールド、定数値）

Firestore / Storage へは直接アクセスしない。

提供する依存と、`context.read` で受け取る主な利用元（型推論の `context.read()` を含む）:

| 型 | 主な利用元 |
|---|---|
| `ImageService` | `ui/post/post_add_dialog.dart`（`PostAddViewModel` へ渡す） |
| `LocationService` | `ui/map/map_screen.dart` |
| `GeocodingService` | `ui/map/widgets/map_search_bar.dart` |
| `PushNotificationService` | `app/main_shell.dart`, `ui/notification/notification_page.dart` |
| `AuthRepository` | `app/main_shell.dart`, `ui/auth/*`, `ui/album/*`, `ui/contest/*`, `ui/event/*`, `ui/core/widgets/comment_section.dart`, `reaction_bar.dart`, `ui/notification/*`, `ui/profile/profile_page.dart`, `ui/post/post_add_dialog.dart`, `ui/post/widgets/post_detail_view.dart` |
| `UserRepository` | `ui/auth/auth_gate.dart`, `ui/album/*`, `ui/contest/contest_detail_page.dart`, `ui/core/widgets/comment_section.dart`, `post_card.dart`, `ui/event/*`, `ui/notification/notification_page.dart`, `ui/profile/*`, `ui/post/widgets/post_detail_view.dart` |
| `PostRepository` | `ui/album/album_detail_page.dart`, `ui/feed/feed_page.dart`, `ui/map/map_screen.dart`, `ui/notification/notification_page.dart`, `ui/profile/profile_page.dart`, `ui/post/post_add_dialog.dart`, `ui/post/widgets/post_detail_view.dart` |
| `ContestRepository` | `ui/contest/*`, `ui/post/post_add_dialog.dart`, `ui/post/widgets/post_detail_view.dart` |
| `CommentRepository` | `ui/core/widgets/comment_section.dart`, `post_card.dart` |
| `ReactionRepository` | `ui/core/widgets/reaction_bar.dart` |
| `AlbumRepository` | `ui/album/*` |
| `EventRepository` | `ui/event/*` |
| `NotificationRepository` | `ui/notification/notification_page.dart`, `widgets/notification_bell.dart` |
| `ReleaseNoteRepository` | `ui/info/release_notes_page.dart` |
| `UsageGuideRepository` | `ui/map/map_screen.dart` |

## 7. 例外・エラー処理（例外の扱い・戻り値・表示メッセージ）

- 本ファイルでは例外を捕捉しない。
- `Firebase.initializeApp` 前に既定の `.instance` を使う Repository へアクセスすると、各 Repository のコンストラクタで Firebase SDK の例外が発生する。`late final` による遅延生成のため、`AppDependencies()` の生成自体では発生しない。
- `DependencyScope` の外で `context.read<T>()` すると `provider` の `ProviderNotFoundException` になる。

## 8. テスト観点（既存テストが確認していること / 未テストの観点）

- 既存テスト（間接）: ウィジェットテストが `AppDependencies(firestore: FakeFirebaseFirestore(), storage: MockFirebaseStorage(), auth: MockFirebaseAuth(), ...)` や `AppDependencies(geocodingService: ...)` のように部分的に差し替え、`withDependencies` で提供して画面を検証している。差し替えと Provider 提供が機能することはこれらで担保される。
- 未テスト: 遅延生成（未使用の依存が生成されないこと）、`postRepository` 差し替え時に `contestRepository` がそれを使うこと、の直接検証。

## 9. 備考・既知の課題

- 新しい Repository / Service を追加したら、`AppDependencies` のコンストラクタ引数・private フィールド・`late final` プロパティと、`DependencyScope` の `Provider` の 4 箇所に追加する（CLAUDE.md の規約）。
- `PushNotificationService` は `messaging` 引数を持つが、`AppDependencies` からは渡さない（常に `FirebaseMessaging.instance` を遅延取得する）。差し替えたい場合は `pushNotificationService` ごと渡す。
- `ReleaseNoteRepository` / `UsageGuideRepository` は Firebase を使わないため引数なしで生成する。
