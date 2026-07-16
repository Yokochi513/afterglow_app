import 'package:afterglow_app/models/comment.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// コメントの読み書きを担うサービス（§6.3）。
/// コメントは `posts/{postId}/comments` サブコレクションに保存する（§3.4）。
class CommentService {
  CommentService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  static const String postsCollection = 'posts';
  static const String commentsCollection = 'comments';

  CollectionReference<Map<String, dynamic>> _commentsRef(String postId) =>
      _firestore
          .collection(postsCollection)
          .doc(postId)
          .collection(commentsCollection);

  /// 指定投稿のコメントを古い順（`createdAt` 昇順）に購読する。
  /// スレッド表示のため、先に投稿されたコメントが上に並ぶ。
  Stream<List<Comment>> getComments(String postId) {
    return _commentsRef(postId)
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => Comment.fromSnapshot(doc.id, doc.data()))
              .toList(growable: false),
        );
  }

  /// コメントを追加する。[comment] の `id` が空文字なら Firestore が採番する。
  Future<bool> addComment(Comment comment) async {
    try {
      final collection = _commentsRef(comment.postId);
      final docRef = comment.id.isEmpty
          ? collection.doc()
          : collection.doc(comment.id);
      await docRef.set(comment.toMap());
      return true;
    } catch (_) {
      return false;
    }
  }

  /// コメント本文を更新する。編集日時（`updatedAt`）も記録する（PS_05）。
  /// 本人のみ更新できることは Firestore ルールで担保する（§7.2）。
  Future<bool> updateComment(
    String postId,
    String commentId,
    String text,
  ) async {
    try {
      await _commentsRef(postId).doc(commentId).update({
        'text': text,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  /// コメントを削除する。本人のみ削除できることは Firestore ルールで担保する（§7.2）。
  Future<bool> deleteComment(String postId, String commentId) async {
    try {
      await _commentsRef(postId).doc(commentId).delete();
      return true;
    } catch (_) {
      return false;
    }
  }
}
