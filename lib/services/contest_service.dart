import 'package:afterglow_app/models/contest.dart';
import 'package:afterglow_app/models/post.dart';
import 'package:afterglow_app/services/post_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ContestService {
  ContestService({FirebaseFirestore? firestore, PostService? postService})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _postService = postService ?? PostService(firestore: firestore);

  final FirebaseFirestore _firestore;
  final PostService _postService;

  static const String contestsCollection = 'contests';
  static const String votesCollection = 'votes';
  static const String postsCollection = PostService.postsCollection;

  CollectionReference<Map<String, dynamic>> get _contestsRef =>
      _firestore.collection(contestsCollection);

  CollectionReference<Map<String, dynamic>> _votesRef(String contestId) =>
      _contestsRef.doc(contestId).collection(votesCollection);

  DocumentReference<Map<String, dynamic>> _postRef(String postId) =>
      _firestore.collection(postsCollection).doc(postId);

  Stream<List<Contest>> getContests() {
    return _contestsRef
        .orderBy('entryDeadline', descending: false)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => Contest.fromSnapshot(doc.id, doc.data()))
              .toList(growable: false),
        );
  }

  Stream<Contest?> watchContest(String contestId) {
    return _contestsRef.doc(contestId).snapshots().map((snapshot) {
      final data = snapshot.data();
      if (data == null) {
        return null;
      }
      return Contest.fromSnapshot(snapshot.id, data);
    });
  }

  Future<Contest?> getContest(String contestId) async {
    final snapshot = await _contestsRef.doc(contestId).get();
    final data = snapshot.data();
    if (data == null) {
      return null;
    }
    return Contest.fromSnapshot(snapshot.id, data);
  }

  Stream<List<Contest>> getEntryOpenContests() {
    return getContests().map(
      (contests) => contests
          .where((contest) => contest.phase == ContestPhase.entry)
          .toList(growable: false),
    );
  }

  Future<bool> createContest(Contest contest) async {
    try {
      final docRef = contest.id.isEmpty
          ? _contestsRef.doc()
          : _contestsRef.doc(contest.id);
      await docRef.set(contest.toMap());
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> updateContest(Contest contest) async {
    try {
      await _contestsRef.doc(contest.id).update({
        'title': contest.title,
        'description': contest.description,
        'entryDeadline': Timestamp.fromDate(contest.entryDeadline),
        'votingDeadline': Timestamp.fromDate(contest.votingDeadline),
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> deleteContest(String contestId) async {
    try {
      await _contestsRef.doc(contestId).delete();
      return true;
    } catch (_) {
      return false;
    }
  }

  Stream<List<Post>> getEntries(String contestId) {
    return _postService.getPostsByContest(contestId);
  }

  Stream<String?> watchUserVote(String contestId, String userId) {
    return _votesRef(contestId).doc(userId).snapshots().map((snapshot) {
      return snapshot.data()?['postId'] as String?;
    });
  }

  Future<void> voteFor(String contestId, String postId, String voterId) async {
    final authorId = await _postService.getAuthorId(postId);
    if (authorId == voterId) {
      throw StateError('自分の投稿には投票できません。');
    }

    return _firestore.runTransaction((transaction) async {
      final contestRef = _contestsRef.doc(contestId);
      final contestSnapshot = await transaction.get(contestRef);
      final contestData = contestSnapshot.data();
      if (contestData == null) {
        throw StateError('コンテストが見つかりません。');
      }
      final contest = Contest.fromSnapshot(contestId, contestData);
      if (contest.phaseAt(DateTime.now()) != ContestPhase.voting) {
        throw StateError('投票期間外です。');
      }

      final newPostRef = _postRef(postId);
      final newPostSnapshot = await transaction.get(newPostRef);
      if (!newPostSnapshot.exists ||
          newPostSnapshot.data()?['contestId'] != contestId) {
        throw StateError('このコンテストの投稿ではありません。');
      }

      final voteRef = _votesRef(contestId).doc(voterId);
      final voteSnapshot = await transaction.get(voteRef);
      final previousPostId = voteSnapshot.data()?['postId'] as String?;
      if (previousPostId == postId) {
        return;
      }

      // voteCount は Cloud Functions の onContestVoteChange が
      // このドキュメントの変更を検知して更新する（firestore.rules は
      // posts/{postId}.voteCount へのクライアント直接書き込みを許可しない）。
      transaction.set(voteRef, {
        'postId': postId,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
    });
  }
}
