import 'package:afterglow_app/models/post.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Post.fromSnapshot', () {
    test('maps a fully populated document', () {
      final createdAt = DateTime(2026, 4, 18, 10, 30);
      final post = Post.fromSnapshot('post-1', <String, dynamic>{
        'userId': 'user-1',
        'caption': 'sunset view',
        'imageUrls': <String>['https://example.com/1.jpg'],
        'latitude': 35.6895,
        'longitude': 139.6917,
        'createdAt': Timestamp.fromDate(createdAt),
      });

      expect(post.id, 'post-1');
      expect(post.userId, 'user-1');
      expect(post.caption, 'sunset view');
      expect(post.imageUrls, <String>['https://example.com/1.jpg']);
      expect(post.latitude, 35.6895);
      expect(post.longitude, 139.6917);
      expect(post.createdAt, createdAt);
    });

    test('defaults caption to an empty string when missing', () {
      final post = Post.fromSnapshot('post-1', <String, dynamic>{
        'userId': 'user-1',
        'createdAt': Timestamp.fromDate(DateTime(2026, 1, 1)),
      });

      expect(post.caption, '');
    });

    test('defaults imageUrls to an empty list when missing', () {
      final post = Post.fromSnapshot('post-1', <String, dynamic>{
        'userId': 'user-1',
        'createdAt': Timestamp.fromDate(DateTime(2026, 1, 1)),
      });

      expect(post.imageUrls, isEmpty);
    });

    test('coerces integer coordinates to doubles', () {
      final post = Post.fromSnapshot('post-1', <String, dynamic>{
        'userId': 'user-1',
        'latitude': 35,
        'longitude': 139,
        'createdAt': Timestamp.fromDate(DateTime(2026, 1, 1)),
      });

      expect(post.latitude, 35.0);
      expect(post.longitude, 139.0);
    });

    test('defaults coordinates to 0.0 when missing', () {
      final post = Post.fromSnapshot('post-1', <String, dynamic>{
        'userId': 'user-1',
        'createdAt': Timestamp.fromDate(DateTime(2026, 1, 1)),
      });

      expect(post.latitude, 0.0);
      expect(post.longitude, 0.0);
    });

    test('falls back to roughly now when createdAt is missing', () {
      final before = DateTime.now();
      final post = Post.fromSnapshot('post-1', <String, dynamic>{
        'userId': 'user-1',
      });
      final after = DateTime.now();

      expect(
        post.createdAt.isBefore(before.subtract(const Duration(seconds: 1))),
        isFalse,
      );
      expect(
        post.createdAt.isAfter(after.add(const Duration(seconds: 1))),
        isFalse,
      );
    });

    test('copies imageUrls into a new modifiable list', () {
      final source = <String>['https://example.com/1.jpg'];
      final post = Post.fromSnapshot('post-1', <String, dynamic>{
        'userId': 'user-1',
        'imageUrls': source,
        'createdAt': Timestamp.fromDate(DateTime(2026, 1, 1)),
      });

      post.imageUrls.add('https://example.com/2.jpg');

      expect(source, hasLength(1));
      expect(post.imageUrls, hasLength(2));
    });
  });
}
