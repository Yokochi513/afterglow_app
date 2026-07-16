import 'package:afterglow_app/services/reaction_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ReactionService', () {
    late FakeFirebaseFirestore firestore;
    late ReactionService service;

    DocumentReference<Map<String, dynamic>> postRef(String postId) =>
        firestore.collection(ReactionService.postsCollection).doc(postId);

    CollectionReference<Map<String, dynamic>> reactionsRef(String postId) =>
        postRef(postId).collection(ReactionService.reactionsCollection);

    Future<int> likeCountOf(String postId) async =>
        (await postRef(postId).get()).data()!['likeCount'] as int;

    setUp(() async {
      firestore = FakeFirebaseFirestore();
      service = ReactionService(firestore: firestore);
      await postRef(
        'post-1',
      ).set({'userId': 'author-1', 'caption': 'テスト投稿', 'likeCount': 0});
    });

    test('toggleReaction がリアクションを追加し likeCount を増やす', () async {
      await service.toggleReaction('post-1', 'user-1');

      final doc = await reactionsRef('post-1').doc('user-1').get();
      expect(doc.exists, isTrue);
      expect(doc.data()!['userId'], 'user-1');
      expect(doc.data()!['type'], ReactionService.likeType);
      expect(doc.data()!['createdAt'], isA<Timestamp>());
      expect(await likeCountOf('post-1'), 1);
    });

    test('同じユーザーの再 toggleReaction が解除になり likeCount を戻す', () async {
      await service.toggleReaction('post-1', 'user-1');
      await service.toggleReaction('post-1', 'user-1');

      final doc = await reactionsRef('post-1').doc('user-1').get();
      expect(doc.exists, isFalse);
      expect(await likeCountOf('post-1'), 0);
    });

    test('ドキュメントIDが userId になり 1 ユーザー 1 リアクションになる（§3.5）', () async {
      await service.toggleReaction('post-1', 'user-1');
      await service.toggleReaction('post-1', 'user-2');

      final snapshot = await reactionsRef('post-1').get();
      expect(
        snapshot.docs.map((doc) => doc.id),
        containsAll(['user-1', 'user-2']),
      );
      expect(snapshot.docs, hasLength(2));
      expect(await likeCountOf('post-1'), 2);
    });

    test('getReactionCount がリアクション数の変化を通知する', () async {
      expect(service.getReactionCount('post-1'), emitsInOrder(<int>[0, 1, 2]));

      await service.toggleReaction('post-1', 'user-1');
      await service.toggleReaction('post-1', 'user-2');
    });

    test('hasReacted が自分のリアクション状態の変化を通知する', () async {
      expect(
        service.hasReacted('post-1', 'user-1'),
        emitsInOrder(<bool>[false, true, false]),
      );

      await service.toggleReaction('post-1', 'user-1');
      await service.toggleReaction('post-1', 'user-1');
    });

    test('hasReacted は他ユーザーのリアクションでは true にならない', () async {
      await service.toggleReaction('post-1', 'user-2');

      expect(await service.hasReacted('post-1', 'user-1').first, isFalse);
      expect(await service.hasReacted('post-1', 'user-2').first, isTrue);
    });
  });
}
