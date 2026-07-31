import 'package:afterglow_app/models/post.dart';
import 'package:afterglow_app/services/image_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

class PostService {
  PostService({
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
    ImageService? imageService,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _storage = storage ?? FirebaseStorage.instance,
       _imageService = imageService ?? ImageService();

  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;
  final ImageService _imageService;

  static const String postsCollection = 'posts';

  /// フィードの 1 ページあたりの取得件数（§8.2 / NFR_02）。
  static const int feedPageSize = 20;

  Future<bool> createPost(Post post, List<XFile> imageFiles) async {
    try {
      final imageUrls = await Future.wait(
        imageFiles.asMap().entries.map((entry) async {
          final index = entry.key;
          final imageFile = entry.value;
          final storageRef = _storage.ref().child(
            'posts/${post.userId}/${post.id}_$index.jpg',
          );

          // アップロード前に短辺2048px・品質85%へ圧縮する（§8.1 / NFR_02）
          final compressedBytes = await _imageService.compressImage(imageFile);

          final uploadTask = await storageRef.putData(
            compressedBytes,
            SettableMetadata(
              contentType: 'image/jpeg',
              // 投稿画像は不変なので長期キャッシュを許可し、CDN/クライアント
              // キャッシュを効かせて2回目以降のロードを高速化する
              cacheControl: 'public, max-age=31536000, immutable',
            ),
          );
          return uploadTask.ref.getDownloadURL();
        }),
      );

      await _firestore.collection(postsCollection).doc(post.id).set({
        'userId': post.userId,
        'caption': post.caption,
        'imageUrls': imageUrls,
        'latitude': post.latitude,
        'longitude': post.longitude,
        'locationName': post.locationName,
        'tags': post.tags,
        // 新規投稿のいいね数・コメント数は必ず 0 から始まる
        'likeCount': 0,
        'commentCount': 0,
        'createdAt': Timestamp.fromDate(post.createdAt),
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  /// 投稿の説明文と画像一覧を更新する。写真の追加は行わず、削除のみを許可する。
  /// Firestore を更新した後、削除された画像（`removedImageUrls`）を Storage から
  /// 削除する。Storage の削除に失敗しても投稿の更新自体は成功扱いとする。
  ///
  /// [latitude] と [longitude] を両方渡したときだけ投稿位置も更新する
  /// （Issue #37）。null の場合は既存の位置を変更しない。
  ///
  /// 画像の Storage パスはインデックス命名に依存せず、ダウンロード URL から
  /// 直接参照（`refFromURL`）して削除するため、途中の画像を削除しても
  /// 残りの画像との対応がずれない。
  Future<bool> updatePost(
    Post post, {
    required String caption,
    required List<String> imageUrls,
    required List<String> removedImageUrls,
    double? latitude,
    double? longitude,
  }) async {
    try {
      await _firestore.collection(postsCollection).doc(post.id).update({
        'caption': caption,
        'imageUrls': imageUrls,
        // 位置は選び直したときだけ更新する（Issue #37）
        if (latitude != null && longitude != null) ...{
          'latitude': latitude,
          'longitude': longitude,
        },
        // 編集日時を記録する（PS_08）
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
    } catch (_) {
      return false;
    }

    await Future.wait(
      removedImageUrls.map((url) async {
        try {
          await _storage.refFromURL(url).delete();
        } catch (_) {
          // 画像が既に存在しない等で失敗しても投稿更新は成功とみなす
        }
      }),
    );

    return true;
  }

  /// 投稿を削除する。Firestore ドキュメントを削除した後、作成時と同じ命名規則で
  /// Storage 上の画像も削除する。Storage の削除に失敗しても、投稿は一覧・マップ
  /// から消えるため削除自体は成功扱いとする。
  Future<bool> deletePost(Post post) async {
    try {
      await _firestore.collection(postsCollection).doc(post.id).delete();
    } catch (_) {
      return false;
    }

    await Future.wait(
      List.generate(post.imageUrls.length, (index) async {
        try {
          await _storage
              .ref()
              .child('posts/${post.userId}/${post.id}_$index.jpg')
              .delete();
        } catch (_) {
          // 画像が既に存在しない等で失敗しても投稿削除は成功とみなす
        }
      }),
    );

    return true;
  }

  Stream<List<Post>> getPosts() {
    return _firestore.collection(postsCollection).snapshots().map((event) {
      return event.docs.reversed
          .map((document) => Post.fromSnapshot(document.id, document.data()))
          .toList(growable: false);
    });
  }

  /// フィードの先頭ページ（最新 [limit] 件）を購読する。新規投稿や編集が
  /// リアルタイムに反映される。続きは [getPostsPage] で追加取得する（§8.2）。
  Stream<PostPage> watchPosts({int limit = feedPageSize}) {
    return _feedQuery(
      limit: limit,
    ).snapshots().map((snapshot) => PostPage.fromSnapshot(snapshot, limit));
  }

  /// [startAfter] の次のページを最新順に取得する。無限スクロールの追加読み込み用。
  /// [startAfter] には直前のページの [PostPage.lastDocument] を渡す（§8.2）。
  Future<PostPage> getPostsPage({
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
    int limit = feedPageSize,
  }) async {
    final snapshot = await _feedQuery(
      limit: limit,
      startAfter: startAfter,
    ).get();
    return PostPage.fromSnapshot(snapshot, limit);
  }

  /// 最新投稿順・[limit] 件のフィード用クエリ。
  /// `limit` は `startAfterDocument` の後に付ける（先に付けるとカーソル適用前に
  /// 件数が切られる実装があるため）。
  Query<Map<String, dynamic>> _feedQuery({
    required int limit,
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
  }) {
    Query<Map<String, dynamic>> query = _firestore
        .collection(postsCollection)
        .orderBy('createdAt', descending: true);
    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }
    return query.limit(limit);
  }

  /// [postIds] の投稿をその並び順のまま取得する。アルバム詳細のグリッド用
  /// （PS_02）。`whereIn` は 1 クエリ 10 件までの制約があるため、ID 指定で
  /// 個別に引いて件数制限を受けないようにしている。
  /// 既に削除された投稿は結果から除外する。
  Future<List<Post>> getPostsByIds(List<String> postIds) async {
    if (postIds.isEmpty) {
      return const [];
    }

    final documents = await Future.wait(
      postIds.map((id) => _firestore.collection(postsCollection).doc(id).get()),
    );

    return documents
        .where((document) => document.exists)
        .map((document) => Post.fromSnapshot(document.id, document.data()!))
        .toList(growable: false);
  }

  /// 指定ユーザーの投稿を新しい順に購読する。プロフィールの投稿グリッド用。
  Stream<List<Post>> getUserPosts(String userId) {
    return _firestore
        .collection(postsCollection)
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((event) {
          final posts = event.docs
              .map(
                (document) => Post.fromSnapshot(document.id, document.data()),
              )
              .toList();
          posts.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return posts;
        });
  }
}

/// フィードの 1 ページ分の取得結果。
///
/// [lastDocument] は次ページ取得（`startAfterDocument`）のカーソルで、UI 側は
/// 中身を解釈せずそのまま [PostService.getPostsPage] に渡す。
class PostPage {
  const PostPage({
    required this.posts,
    required this.lastDocument,
    required this.hasMore,
  });

  factory PostPage.fromSnapshot(
    QuerySnapshot<Map<String, dynamic>> snapshot,
    int limit,
  ) {
    return PostPage(
      posts: snapshot.docs
          .map((document) => Post.fromSnapshot(document.id, document.data()))
          .toList(growable: false),
      lastDocument: snapshot.docs.isEmpty ? null : snapshot.docs.last,
      // 取得件数が limit に満たなければ、それが最後のページ。
      hasMore: snapshot.docs.length == limit,
    );
  }

  final List<Post> posts;
  final DocumentSnapshot<Map<String, dynamic>>? lastDocument;
  final bool hasMore;
}
