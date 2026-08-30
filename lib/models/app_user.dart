import 'package:cloud_firestore/cloud_firestore.dart';

/// users/{uid} の公開プロフィール。
///
/// メールアドレス等の個人情報は本人のみ読み書きできる
/// `users/{uid}/private/profile` に分離して保持する（本ドキュメントは
/// 投稿者名表示のためログイン済みユーザー全員に公開されるため）。
class AppUser {
  const AppUser({
    required this.id,
    required this.username,
    this.bio = '',
    this.profileImageUrl,
    this.role = 'member',
    this.approved = false,
    required this.createdAt,
  });

  final String id;
  final String username;
  final String bio;
  final String? profileImageUrl;
  final String role;
  final bool approved;
  final DateTime createdAt;

  bool get isAdmin => role == 'admin';

  factory AppUser.fromSnapshot(String id, Map<String, dynamic> document) {
    return AppUser(
      id: id,
      username: document['username'] ?? '',
      bio: document['bio'] ?? '',
      profileImageUrl: document['profileImageUrl'],
      role: document['role'] ?? 'member',
      approved: document['approved'] ?? false,
      createdAt:
          (document['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'username': username,
      'bio': bio,
      'profileImageUrl': profileImageUrl,
      'role': role,
      'approved': approved,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
