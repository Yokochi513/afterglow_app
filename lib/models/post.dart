import 'package:cloud_firestore/cloud_firestore.dart';

class Post {
  const Post({
    required this.id,
    required this.userId,
    required this.caption,
    required this.imageUrls,
    required this.latitude,
    required this.longitude,
    required this.createdAt,
    this.locationName,
    this.tags = const [],
    this.likeCount = 0,
    this.commentCount = 0,
    this.updatedAt,
  });

  final String id;
  final String userId;
  final String caption;
  final List<String> imageUrls;
  final double latitude;
  final double longitude;
  final DateTime createdAt;

  /// 場所名（自由入力）。未設定なら null。
  final String? locationName;

  /// タグ一覧（PS_03）。欠損時は空配列。
  final List<String> tags;

  /// いいね数（非正規化）。欠損時は 0。
  final int likeCount;

  /// コメント数（非正規化）。フィードのカードが投稿ごとに
  /// comments サブコレクションを数えずに済むよう保持する。欠損時は 0。
  final int commentCount;

  /// 更新日時（PS_08）。未編集なら null。
  final DateTime? updatedAt;

  factory Post.fromSnapshot(String id, Map<String, dynamic> document) {
    return Post(
      id: id,
      userId: document['userId'],
      caption: document['caption'] ?? '',
      imageUrls: List<String>.from(document['imageUrls'] ?? []),
      latitude: document['latitude']?.toDouble() ?? 0.0,
      longitude: document['longitude']?.toDouble() ?? 0.0,
      createdAt:
          (document['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      locationName: document['locationName'],
      tags: List<String>.from(document['tags'] ?? []),
      likeCount: document['likeCount'] ?? 0,
      commentCount: document['commentCount'] ?? 0,
      updatedAt: (document['updatedAt'] as Timestamp?)?.toDate(),
    );
  }
}
