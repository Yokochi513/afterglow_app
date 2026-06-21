import 'package:afterglow_app/models/post.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

class PostService {
  PostService({FirebaseFirestore? firestore, FirebaseStorage? storage})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _storage = storage ?? FirebaseStorage.instance;

  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

  static const String postsCollection = 'posts';

  Future<bool> createPost(Post post, List<XFile> imageFiles) async {
    try {
      final imageUrls = await Future.wait(
        imageFiles.asMap().entries.map((entry) async {
          final index = entry.key;
          final imageFile = entry.value;
          final storageRef = _storage.ref().child(
            'posts/${post.userId}/${post.id}_$index.jpg',
          );

          final uploadTask = await storageRef.putData(
            await imageFile.readAsBytes(),
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
  /// 画像の Storage パスはインデックス命名に依存せず、ダウンロード URL から
  /// 直接参照（`refFromURL`）して削除するため、途中の画像を削除しても
  /// 残りの画像との対応がずれない。
  Future<bool> updatePost(
    Post post, {
    required String caption,
    required List<String> imageUrls,
    required List<String> removedImageUrls,
  }) async {
    try {
      await _firestore.collection(postsCollection).doc(post.id).update({
        'caption': caption,
        'imageUrls': imageUrls,
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
