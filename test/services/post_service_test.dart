import 'dart:io';
import 'dart:typed_data';

import 'package:afterglow_app/models/post.dart';
import 'package:afterglow_app/services/image_service.dart';
import 'package:afterglow_app/services/post_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_storage_mocks/firebase_storage_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';

/// 圧縮はプラットフォームチャネルに依存し VM テストで実行できないため、
/// テストでは元のバイト列をそのまま返すダミーに差し替える。
class _PassthroughImageService extends ImageService {
  @override
  Future<Uint8List> compressImage(XFile image) => image.readAsBytes();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PostService', () {
    late FakeFirebaseFirestore firestore;
    late MockFirebaseStorage storage;
    late PostService service;

    setUp(() {
      firestore = FakeFirebaseFirestore();
      storage = MockFirebaseStorage();
      service = PostService(
        firestore: firestore,
        storage: storage,
        imageService: _PassthroughImageService(),
      );
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
        locationName: '大阪城',
        tags: const ['桜', '夜景'],
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
      expect(data['locationName'], '大阪城');
      expect(List<String>.from(data['tags'] as List<dynamic>), <String>[
        '桜',
        '夜景',
      ]);
      expect(data['likeCount'], 0);

      final imageUrls = List<String>.from(data['imageUrls'] as List<dynamic>);
      expect(imageUrls, hasLength(1));
      expect(imageUrls.first, isNotEmpty);
    });

    test('createPost uploads multiple images with distinct URLs', () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'post_service_test_multi',
      );
      addTearDown(() async {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });

      final firstImage = await File(
        '${tempDir.path}/image_1.jpg',
      ).writeAsBytes(<int>[1, 2, 3]);
      final secondImage = await File(
        '${tempDir.path}/image_2.jpg',
      ).writeAsBytes(<int>[4, 5, 6]);

      final post = Post(
        id: 'post-multi',
        userId: 'user-1',
        caption: 'two images',
        imageUrls: const [],
        latitude: 35.6895,
        longitude: 139.6917,
        createdAt: DateTime(2026, 4, 18, 11, 0),
      );

      final success = await service.createPost(post, [
        XFile(firstImage.path),
        XFile(secondImage.path),
      ]);

      expect(success, isTrue);

      final snapshot = await firestore
          .collection(PostService.postsCollection)
          .doc(post.id)
          .get();

      final data = snapshot.data();
      expect(data, isNotNull);

      final imageUrls = List<String>.from(data!['imageUrls'] as List<dynamic>);
      expect(imageUrls, hasLength(2));
      expect(imageUrls[0], isNotEmpty);
      expect(imageUrls[1], isNotEmpty);
      expect(imageUrls[0], isNot(imageUrls[1]));
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

    test('getPosts emits an empty list when there are no posts', () async {
      final posts = await service.getPosts().first;

      expect(posts, isEmpty);
    });

    test('getPosts stream emits again when a post is added', () async {
      final emissions = <List<Post>>[];
      final subscription = service.getPosts().listen(emissions.add);
      addTearDown(subscription.cancel);

      await firestore
          .collection(PostService.postsCollection)
          .doc('post-1')
          .set(
            _toDocument(
              Post(
                id: 'post-1',
                userId: 'user-1',
                caption: 'live post',
                imageUrls: const [],
                latitude: 35.0,
                longitude: 139.0,
                createdAt: DateTime(2026, 4, 18, 9, 0),
              ),
            ),
          );

      await Future<void>.delayed(Duration.zero);

      expect(emissions.last, hasLength(1));
      expect(emissions.last.single.caption, 'live post');
    });

    test(
      'createPost succeeds and stores no URLs when given no images',
      () async {
        final post = Post(
          id: 'post-no-image',
          userId: 'user-1',
          caption: 'text only',
          imageUrls: const [],
          latitude: 35.0,
          longitude: 139.0,
          createdAt: DateTime(2026, 4, 18, 12, 0),
        );

        final success = await service.createPost(post, const []);

        expect(success, isTrue);

        final snapshot = await firestore
            .collection(PostService.postsCollection)
            .doc(post.id)
            .get();
        final data = snapshot.data();
        expect(data, isNotNull);
        expect(data!['imageUrls'], isEmpty);
      },
    );

    test(
      'createPost stores images under the user/post namespaced path',
      () async {
        final tempDir = await Directory.systemTemp.createTemp(
          'post_service_test_path',
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
          id: 'post-path',
          userId: 'user-42',
          caption: 'path check',
          imageUrls: const [],
          latitude: 35.0,
          longitude: 139.0,
          createdAt: DateTime(2026, 4, 18, 13, 0),
        );

        await service.createPost(post, [XFile(imageFile.path)]);

        final snapshot = await firestore
            .collection(PostService.postsCollection)
            .doc(post.id)
            .get();
        final imageUrls = List<String>.from(
          snapshot.data()!['imageUrls'] as List<dynamic>,
        );

        expect(imageUrls.single, contains('posts/user-42/post-path_0.jpg'));
      },
    );

    test('deletePost removes the post document and its images', () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'post_service_test_delete',
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
        id: 'post-delete',
        userId: 'user-1',
        caption: 'to be deleted',
        imageUrls: const [],
        latitude: 35.0,
        longitude: 139.0,
        createdAt: DateTime(2026, 4, 18, 15, 0),
      );

      await service.createPost(post, [XFile(imageFile.path)]);

      final created = await firestore
          .collection(PostService.postsCollection)
          .doc(post.id)
          .get();
      final storedUrls = List<String>.from(
        created.data()!['imageUrls'] as List<dynamic>,
      );

      final success = await service.deletePost(
        Post(
          id: post.id,
          userId: post.userId,
          caption: post.caption,
          imageUrls: storedUrls,
          latitude: post.latitude,
          longitude: post.longitude,
          createdAt: post.createdAt,
        ),
      );

      expect(success, isTrue);

      final snapshot = await firestore
          .collection(PostService.postsCollection)
          .doc(post.id)
          .get();
      expect(snapshot.exists, isFalse);

      await expectLater(
        () => storage
            .ref()
            .child('posts/user-1/post-delete_0.jpg')
            .getDownloadURL(),
        throwsA(anything),
      );
    });

    test('deletePost succeeds even when the post has no images', () async {
      final post = Post(
        id: 'post-no-image-delete',
        userId: 'user-1',
        caption: 'text only',
        imageUrls: const [],
        latitude: 35.0,
        longitude: 139.0,
        createdAt: DateTime(2026, 4, 18, 16, 0),
      );

      await firestore
          .collection(PostService.postsCollection)
          .doc(post.id)
          .set(_toDocument(post));

      final success = await service.deletePost(post);

      expect(success, isTrue);

      final snapshot = await firestore
          .collection(PostService.postsCollection)
          .doc(post.id)
          .get();
      expect(snapshot.exists, isFalse);
    });

    test(
      'createPost returns false and writes nothing when an image is missing',
      () async {
        final post = Post(
          id: 'post-bad-image',
          userId: 'user-1',
          caption: 'broken',
          imageUrls: const [],
          latitude: 35.0,
          longitude: 139.0,
          createdAt: DateTime(2026, 4, 18, 14, 0),
        );

        final success = await service.createPost(post, [
          XFile('${Directory.systemTemp.path}/does_not_exist.jpg'),
        ]);

        expect(success, isFalse);

        final snapshot = await firestore
            .collection(PostService.postsCollection)
            .doc(post.id)
            .get();
        expect(snapshot.exists, isFalse);
      },
    );

    test('updatePost writes updatedAt along with the edited fields', () async {
      final post = Post(
        id: 'post-update',
        userId: 'user-1',
        caption: 'before',
        imageUrls: const ['https://example.com/1.jpg'],
        latitude: 35.0,
        longitude: 139.0,
        createdAt: DateTime(2026, 4, 18, 17, 0),
      );

      await firestore
          .collection(PostService.postsCollection)
          .doc(post.id)
          .set(_toDocument(post));

      final before = DateTime.now();
      final success = await service.updatePost(
        post,
        caption: 'after',
        imageUrls: const [],
        removedImageUrls: const ['https://example.com/1.jpg'],
      );
      final after = DateTime.now();

      expect(success, isTrue);

      final data =
          (await firestore
                  .collection(PostService.postsCollection)
                  .doc(post.id)
                  .get())
              .data();
      expect(data!['caption'], 'after');

      final updatedAt = (data['updatedAt'] as Timestamp).toDate();
      expect(
        updatedAt.isBefore(before.subtract(const Duration(seconds: 1))),
        isFalse,
      );
      expect(updatedAt.isAfter(after.add(const Duration(seconds: 1))), isFalse);
    });

    test(
      'updatePost updates the position when both coordinates are given',
      () async {
        final post = Post(
          id: 'post-move',
          userId: 'user-1',
          caption: 'before',
          imageUrls: const ['https://example.com/1.jpg'],
          latitude: 35.0,
          longitude: 139.0,
          createdAt: DateTime(2026, 4, 18, 17, 0),
        );

        await firestore
            .collection(PostService.postsCollection)
            .doc(post.id)
            .set(_toDocument(post));

        final success = await service.updatePost(
          post,
          caption: post.caption,
          imageUrls: post.imageUrls,
          removedImageUrls: const [],
          latitude: 34.6695,
          longitude: 133.9511,
        );

        expect(success, isTrue);

        final data =
            (await firestore
                    .collection(PostService.postsCollection)
                    .doc(post.id)
                    .get())
                .data();
        expect(data!['latitude'], 34.6695);
        expect(data['longitude'], 133.9511);
        // 位置編集でも updatedAt は記録される（PS_08）
        expect(data['updatedAt'], isA<Timestamp>());
      },
    );

    test(
      'updatePost keeps the position when coordinates are omitted',
      () async {
        final post = Post(
          id: 'post-stay',
          userId: 'user-1',
          caption: 'before',
          imageUrls: const ['https://example.com/1.jpg'],
          latitude: 35.0,
          longitude: 139.0,
          createdAt: DateTime(2026, 4, 18, 17, 0),
        );

        await firestore
            .collection(PostService.postsCollection)
            .doc(post.id)
            .set(_toDocument(post));

        final success = await service.updatePost(
          post,
          caption: 'after',
          imageUrls: post.imageUrls,
          removedImageUrls: const [],
        );

        expect(success, isTrue);

        final data =
            (await firestore
                    .collection(PostService.postsCollection)
                    .doc(post.id)
                    .get())
                .data();
        expect(data!['latitude'], 35.0);
        expect(data['longitude'], 139.0);
      },
    );

    test(
      'watchPosts returns the newest posts limited to the page size',
      () async {
        await _seedPosts(firestore, count: 5);

        final page = await service.watchPosts(limit: 3).first;

        expect(page.posts.map((post) => post.id).toList(), <String>[
          'post-4',
          'post-3',
          'post-2',
        ]);
        expect(page.hasMore, isTrue);
        expect(page.lastDocument, isNotNull);
      },
    );

    test('getPostsPage continues after the given cursor', () async {
      await _seedPosts(firestore, count: 5);

      final firstPage = await service.getPostsPage(limit: 3);
      final secondPage = await service.getPostsPage(
        startAfter: firstPage.lastDocument,
        limit: 3,
      );

      expect(secondPage.posts.map((post) => post.id).toList(), <String>[
        'post-1',
        'post-0',
      ]);
      // 3 件に満たないので最後のページ。
      expect(secondPage.hasMore, isFalse);
    });

    test(
      'getPostsPage reports no more pages when there are no posts',
      () async {
        final page = await service.getPostsPage();

        expect(page.posts, isEmpty);
        expect(page.lastDocument, isNull);
        expect(page.hasMore, isFalse);
      },
    );

    test('getPostsByIds returns posts in the requested order', () async {
      await _seedPosts(firestore, count: 3);

      final posts = await service.getPostsByIds(['post-2', 'post-0']);

      expect(posts.map((post) => post.id).toList(), ['post-2', 'post-0']);
    });

    test('getPostsByIds skips ids that no longer exist', () async {
      await _seedPosts(firestore, count: 2);

      final posts = await service.getPostsByIds([
        'post-0',
        'deleted',
        'post-1',
      ]);

      expect(posts.map((post) => post.id).toList(), ['post-0', 'post-1']);
    });

    test('getPostsByIds returns an empty list for no ids', () async {
      expect(await service.getPostsByIds(const []), isEmpty);
    });
  });
}

/// createdAt が 1 分ずつ新しくなる投稿を `post-0`..`post-{count-1}` で作成する。
Future<void> _seedPosts(
  FakeFirebaseFirestore firestore, {
  required int count,
}) async {
  for (var index = 0; index < count; index++) {
    await firestore
        .collection(PostService.postsCollection)
        .doc('post-$index')
        .set(
          _toDocument(
            Post(
              id: 'post-$index',
              userId: 'user-1',
              caption: 'post $index',
              imageUrls: const [],
              latitude: 35.0,
              longitude: 139.0,
              createdAt: DateTime(2026, 4, 18, 9, index),
            ),
          ),
        );
  }
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
