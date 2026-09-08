import 'package:afterglow_app/models/contest.dart';
import 'package:afterglow_app/models/post.dart';
import 'package:afterglow_app/services/contest_service.dart';
import 'package:afterglow_app/services/post_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_storage_mocks/firebase_storage_mocks.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ContestService', () {
    late FakeFirebaseFirestore firestore;
    late PostService postService;
    late ContestService contestService;

    setUp(() async {
      firestore = FakeFirebaseFirestore();
      postService = PostService(
        firestore: firestore,
        storage: MockFirebaseStorage(),
      );
      contestService = ContestService(
        firestore: firestore,
        postService: postService,
      );
      await _seedVotingContest(firestore);
      await _seedPost(
        firestore,
        Post(
          id: 'post-1',
          userId: '',
          caption: 'entry 1',
          imageUrls: const [],
          latitude: 35,
          longitude: 139,
          createdAt: DateTime(2026, 9, 8),
          contestId: 'contest-1',
        ),
        authorId: 'author-1',
      );
      await _seedPost(
        firestore,
        Post(
          id: 'post-2',
          userId: '',
          caption: 'entry 2',
          imageUrls: const [],
          latitude: 35,
          longitude: 139,
          createdAt: DateTime(2026, 9, 8),
          contestId: 'contest-1',
        ),
        authorId: 'author-2',
      );
    });

    test('voteFor creates a vote document for the chosen post', () async {
      await contestService.voteFor('contest-1', 'post-1', 'voter');

      final vote = await firestore
          .collection(ContestService.contestsCollection)
          .doc('contest-1')
          .collection(ContestService.votesCollection)
          .doc('voter')
          .get();
      expect(vote.data()?['postId'], 'post-1');

      // voteCount 自体は Cloud Functions の onContestVoteChange が
      // このドキュメントの書き込みを検知して更新する（本テストは
      // fake_cloud_firestore のためトリガーは実行されず、ここでは
      // 投票ドキュメントの内容のみを検証する）。
    });

    test('voteFor switches the vote target', () async {
      await contestService.voteFor('contest-1', 'post-1', 'voter');
      await contestService.voteFor('contest-1', 'post-2', 'voter');

      final vote = await firestore
          .collection(ContestService.contestsCollection)
          .doc('contest-1')
          .collection(ContestService.votesCollection)
          .doc('voter')
          .get();
      expect(vote.data()?['postId'], 'post-2');
    });

    test('voteFor rejects voting for own post', () async {
      await expectLater(
        contestService.voteFor('contest-1', 'post-1', 'author-1'),
        throwsStateError,
      );
    });
  });
}

Future<void> _seedVotingContest(FakeFirebaseFirestore firestore) {
  final now = DateTime.now();
  final contest = Contest(
    id: 'contest-1',
    creatorId: 'creator',
    title: 'contest',
    description: '',
    entryDeadline: now.subtract(const Duration(days: 1)),
    votingDeadline: now.add(const Duration(days: 1)),
    createdAt: now.subtract(const Duration(days: 2)),
    updatedAt: now.subtract(const Duration(days: 2)),
  );
  return firestore
      .collection(ContestService.contestsCollection)
      .doc(contest.id)
      .set(contest.toMap());
}

Future<void> _seedPost(
  FakeFirebaseFirestore firestore,
  Post post, {
  required String authorId,
}) async {
  await firestore.collection(PostService.postsCollection).doc(post.id).set({
    'userId': post.userId,
    'caption': post.caption,
    'imageUrls': post.imageUrls,
    'latitude': post.latitude,
    'longitude': post.longitude,
    'createdAt': Timestamp.fromDate(post.createdAt),
    'contestId': post.contestId,
    'stayAnonymous': post.stayAnonymous,
    'voteCount': post.voteCount,
  });
  await firestore
      .collection(PostService.postsCollection)
      .doc(post.id)
      .collection(PostService.privateCollection)
      .doc(PostService.authorDocument)
      .set({'userId': authorId});
}
