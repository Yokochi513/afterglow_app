import 'package:cloud_firestore/cloud_firestore.dart';

class AppUser {
  const AppUser({
    required this.id,
    required this.username,
    required this.email,
    this.bio = '',
    this.profileImageUrl,
    this.role = 'member',
    this.approved = false,
    this.emailNotification = true,
    required this.createdAt,
  });

  final String id;
  final String username;
  final String email;
  final String bio;
  final String? profileImageUrl;
  final String role;
  final bool approved;
  final bool emailNotification;
  final DateTime createdAt;

  bool get isAdmin => role == 'admin';

  factory AppUser.fromSnapshot(String id, Map<String, dynamic> document) {
    return AppUser(
      id: id,
      username: document['username'] ?? '',
      email: document['email'] ?? '',
      bio: document['bio'] ?? '',
      profileImageUrl: document['profileImageUrl'],
      role: document['role'] ?? 'member',
      approved: document['approved'] ?? false,
      emailNotification: document['emailNotification'] ?? true,
      createdAt:
          (document['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'username': username,
      'email': email,
      'bio': bio,
      'profileImageUrl': profileImageUrl,
      'role': role,
      'approved': approved,
      'emailNotification': emailNotification,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
