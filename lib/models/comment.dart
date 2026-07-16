import 'package:cloud_firestore/cloud_firestore.dart';

/// 投稿へのコメント（PS_05 / §3.4）。`posts/{postId}/comments/{commentId}` に
/// 保存されるテキストのみのコメント。イミュータブル。
class Comment {
  const Comment({
    required this.id,
    required this.postId,
    required this.userId,
    required this.text,
    required this.createdAt,
    this.updatedAt,
  });

  final String id;

  /// 親 post の ID。
  final String postId;

  /// コメント投稿者の UID。
  final String userId;

  /// コメント本文（テキストのみ・PS_05）。
  final String text;

  final DateTime createdAt;

  /// 編集日時（PS_05）。未編集なら null。
  final DateTime? updatedAt;

  factory Comment.fromSnapshot(String id, Map<String, dynamic> document) {
    return Comment(
      id: id,
      postId: document['postId'] ?? '',
      userId: document['userId'] ?? '',
      text: document['text'] ?? '',
      createdAt:
          (document['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (document['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'postId': postId,
      'userId': userId,
      'text': text,
      'createdAt': Timestamp.fromDate(createdAt),
      if (updatedAt != null) 'updatedAt': Timestamp.fromDate(updatedAt!),
    };
  }
}
