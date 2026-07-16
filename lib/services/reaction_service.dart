import 'package:cloud_firestore/cloud_firestore.dart';

/// リアクション（いいね）の読み書きを担うサービス（§6.4）。
/// リアクションは `posts/{postId}/reactions/{userId}` に保存する（§3.5）。
///
/// ドキュメントID を userId にすることで 1 ユーザー 1 リアクションを
/// Firestore の構造として保証する。
class ReactionService {
  ReactionService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  static const String postsCollection = 'posts';
  static const String reactionsCollection = 'reactions';

  /// リアクション種別。フェーズ 1 は 'like' のみ（§3.5）。
  static const String likeType = 'like';

  DocumentReference<Map<String, dynamic>> _postRef(String postId) =>
      _firestore.collection(postsCollection).doc(postId);

  DocumentReference<Map<String, dynamic>> _reactionRef(
    String postId,
    String userId,
  ) => _postRef(postId).collection(reactionsCollection).doc(userId);

  /// 指定投稿のリアクション数を購読する。
  Stream<int> getReactionCount(String postId) {
    return _postRef(postId)
        .collection(reactionsCollection)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  /// 指定ユーザーが指定投稿にリアクション済みかを購読する。
  Stream<bool> hasReacted(String postId, String userId) {
    return _reactionRef(postId, userId).snapshots().map((doc) => doc.exists);
  }

  /// リアクションを追加/解除する。併せて `posts/{postId}.likeCount` の
  /// 非正規化カウントを増減する（§3.3）。
  ///
  /// リアクションドキュメントの有無と likeCount の更新がずれないよう、
  /// トランザクションで一括して行う。
  Future<void> toggleReaction(String postId, String userId) {
    return _firestore.runTransaction((transaction) async {
      final reactionRef = _reactionRef(postId, userId);
      final reaction = await transaction.get(reactionRef);

      if (reaction.exists) {
        transaction.delete(reactionRef);
        transaction.update(_postRef(postId), {
          'likeCount': FieldValue.increment(-1),
        });
      } else {
        transaction.set(reactionRef, {
          'userId': userId,
          'type': likeType,
          'createdAt': Timestamp.fromDate(DateTime.now()),
        });
        transaction.update(_postRef(postId), {
          'likeCount': FieldValue.increment(1),
        });
      }
    });
  }
}
