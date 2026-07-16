import 'package:cloud_firestore/cloud_firestore.dart';

/// 投稿をテーマ・イベント単位でまとめるアルバム（PS_02 / §3.6）。
/// `albums/{albumId}` に保存される。イミュータブル。
class Album {
  const Album({
    required this.id,
    required this.ownerId,
    required this.title,
    required this.description,
    required this.createdAt,
    this.postIds = const [],
    this.coverImageUrl,
  });

  final String id;

  /// 作成者の UID。作成・編集できるのは所有者のみ（§7.2）。
  final String ownerId;

  final String title;

  /// アルバムの説明。欠損時は空文字。
  final String description;

  /// 含まれる投稿の ID 一覧。欠損時は空配列。
  final List<String> postIds;

  /// カバー画像 URL。未設定なら null。
  final String? coverImageUrl;

  final DateTime createdAt;

  factory Album.fromSnapshot(String id, Map<String, dynamic> document) {
    return Album(
      id: id,
      ownerId: document['ownerId'] ?? '',
      title: document['title'] ?? '',
      description: document['description'] ?? '',
      postIds: List<String>.from(document['postIds'] ?? []),
      coverImageUrl: document['coverImageUrl'],
      createdAt:
          (document['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'ownerId': ownerId,
      'title': title,
      'description': description,
      'postIds': postIds,
      'coverImageUrl': coverImageUrl,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
