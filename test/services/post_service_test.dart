import 'dart:io';

import 'package:afterglow_app/models/post.dart';
import 'package:afterglow_app/services/post_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_storage_mocks/firebase_storage_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PostService', () {
    late FakeFirebaseFirestore firestore;
    late MockFirebaseStorage storage;
    late PostService service;

    setUp(() {
      firestore = FakeFirebaseFirestore();
      storage = MockFirebaseStorage();
      service = PostService(firestore: firestore, storage: storage);
    });

    test('createPost uploads images and saves the post document', () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'post_service_test',
      );
      addTearDown(() async {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });

      final imageFile = await File(
        '${tempDir.path}/image.jpg',
      ).writeAsBytes(<int>[1, 2, 3]);

      final post = Post(
        id: 'post-1',
        userId: 'user-1',
        caption: 'sunset view',
        imageUrls: const [],
        latitude: 35.6895,
        longitude: 139.6917,
        createdAt: DateTime(2026, 4, 18, 10, 30),
      );

      await service.createPost(post, [XFile(imageFile.path)]);

      final snapshot = await firestore
          .collection(PostService.postsCollection)
          .doc(post.id)
          .get();

      expect(snapshot.exists, isTrue);

      final data = snapshot.data();
      expect(data, isNotNull);
      expect(data!['userId'], post.userId);
      expect(data['caption'], post.caption);
      expect(data['latitude'], post.latitude);
      expect(data['longitude'], post.longitude);
      expect((data['createdAt'] as Timestamp).toDate(), post.createdAt);

      final imageUrls = List<String>.from(data['imageUrls'] as List<dynamic>);
      expect(imageUrls, hasLength(1));
      expect(imageUrls.first, isNotEmpty);
    });

    test('getPosts returns posts in reverse snapshot order', () async {
      final firstPost = Post(
        id: 'post-1',
        userId: 'user-1',
        caption: 'first post',
        imageUrls: const ['https://example.com/1.jpg'],
        latitude: 35.0,
        longitude: 139.0,
        createdAt: DateTime(2026, 4, 18, 9, 0),
      );

      final secondPost = Post(
        id: 'post-2',
        userId: 'user-2',
        caption: 'second post',
        imageUrls: const ['https://example.com/2.jpg'],
        latitude: 36.0,
        longitude: 140.0,
        createdAt: DateTime(2026, 4, 18, 10, 0),
      );

      await firestore
          .collection(PostService.postsCollection)
          .doc(firstPost.id)
          .set(_toDocument(firstPost));
      await firestore
          .collection(PostService.postsCollection)
          .doc(secondPost.id)
          .set(_toDocument(secondPost));

      final posts = await service.getPosts().first;

      expect(posts, hasLength(2));
      expect(posts.map((post) => post.id).toList(), <String>[
        secondPost.id,
        firstPost.id,
      ]);
      expect(posts.first.caption, secondPost.caption);
      expect(posts.last.caption, firstPost.caption);
    });
  });
}

Map<String, dynamic> _toDocument(Post post) {
  return <String, dynamic>{
    'userId': post.userId,
    'caption': post.caption,
    'imageUrls': post.imageUrls,
    'latitude': post.latitude,
    'longitude': post.longitude,
    'createdAt': Timestamp.fromDate(post.createdAt),
  };
}
