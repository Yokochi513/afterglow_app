import 'package:afterglow_app/models/comment.dart';
import 'package:afterglow_app/services/comment_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CommentService', () {
    late FakeFirebaseFirestore firestore;
    late CommentService service;

    setUp(() {
      firestore = FakeFirebaseFirestore();
      service = CommentService(firestore: firestore);
    });

    CollectionReference<Map<String, dynamic>> commentsRef(String postId) =>
        firestore
            .collection(CommentService.postsCollection)
            .doc(postId)
            .collection(CommentService.commentsCollection);

    test('addComment stores the comment in the post subcollection', () async {
      final result = await service.addComment(
        Comment(
          id: '',
          postId: 'post-1',
          userId: 'user-1',
          text: 'すてきな写真ですね',
          createdAt: DateTime(2026, 7, 15, 21, 30),
        ),
      );

      expect(result, isTrue);

      final snapshot = await commentsRef('post-1').get();
      expect(snapshot.docs, hasLength(1));

      final data = snapshot.docs.first.data();
      expect(data['postId'], 'post-1');
      expect(data['userId'], 'user-1');
      expect(data['text'], 'すてきな写真ですね');
      expect(data['createdAt'], isA<Timestamp>());
      expect(data.containsKey('updatedAt'), isFalse);
    });

    test('addComment uses the provided id when it is not empty', () async {
      await service.addComment(
        Comment(
          id: 'fixed-id',
          postId: 'post-1',
          userId: 'user-1',
          text: 'こんにちは',
          createdAt: DateTime(2026, 7, 15),
        ),
      );

      final doc = await commentsRef('post-1').doc('fixed-id').get();
      expect(doc.exists, isTrue);
      expect(doc.data()!['text'], 'こんにちは');
    });

    test('getComments returns comments in ascending createdAt order', () async {
      await service.addComment(
        Comment(
          id: 'c-late',
          postId: 'post-1',
          userId: 'user-1',
          text: '2番目',
          createdAt: DateTime(2026, 7, 15, 12),
        ),
      );
      await service.addComment(
        Comment(
          id: 'c-early',
          postId: 'post-1',
          userId: 'user-2',
          text: '1番目',
          createdAt: DateTime(2026, 7, 15, 10),
        ),
      );

      final comments = await service.getComments('post-1').first;

      expect(comments.map((c) => c.id).toList(), ['c-early', 'c-late']);
      expect(comments.first.text, '1番目');
    });

    test('getComments is scoped to the given post', () async {
      await service.addComment(
        Comment(
          id: '',
          postId: 'post-1',
          userId: 'user-1',
          text: 'post-1 のコメント',
          createdAt: DateTime(2026, 7, 15),
        ),
      );
      await service.addComment(
        Comment(
          id: '',
          postId: 'post-2',
          userId: 'user-1',
          text: 'post-2 のコメント',
          createdAt: DateTime(2026, 7, 15),
        ),
      );

      final comments = await service.getComments('post-1').first;
      expect(comments, hasLength(1));
      expect(comments.first.text, 'post-1 のコメント');
    });

    test('updateComment changes the text and records updatedAt', () async {
      await service.addComment(
        Comment(
          id: 'c-1',
          postId: 'post-1',
          userId: 'user-1',
          text: '編集前',
          createdAt: DateTime(2026, 7, 15),
        ),
      );

      final result = await service.updateComment('post-1', 'c-1', '編集後');
      expect(result, isTrue);

      final doc = await commentsRef('post-1').doc('c-1').get();
      expect(doc.data()!['text'], '編集後');
      expect(doc.data()!['updatedAt'], isA<Timestamp>());
    });

    test('deleteComment removes the comment', () async {
      await service.addComment(
        Comment(
          id: 'c-1',
          postId: 'post-1',
          userId: 'user-1',
          text: '削除対象',
          createdAt: DateTime(2026, 7, 15),
        ),
      );

      final result = await service.deleteComment('post-1', 'c-1');
      expect(result, isTrue);

      final doc = await commentsRef('post-1').doc('c-1').get();
      expect(doc.exists, isFalse);
    });
  });
}
