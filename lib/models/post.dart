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
  });

  final String id;
  final String userId;
  final String caption;
  final List<String> imageUrls;
  final double latitude;
  final double longitude;
  final DateTime createdAt;

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
    );
  }
}
