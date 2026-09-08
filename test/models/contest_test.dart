import 'package:afterglow_app/models/contest.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Contest', () {
    test('fromSnapshot and toMap round trip', () {
      final entryDeadline = DateTime(2026, 9, 10, 12);
      final votingDeadline = DateTime(2026, 9, 20, 12);
      final createdAt = DateTime(2026, 9, 1, 9);
      final updatedAt = DateTime(2026, 9, 2, 9);

      final contest = Contest.fromSnapshot('contest-1', {
        'creatorId': 'creator',
        'title': '夕焼けコンテスト',
        'description': '夕焼け写真を募集します',
        'entryDeadline': Timestamp.fromDate(entryDeadline),
        'votingDeadline': Timestamp.fromDate(votingDeadline),
        'createdAt': Timestamp.fromDate(createdAt),
        'updatedAt': Timestamp.fromDate(updatedAt),
      });

      expect(contest.id, 'contest-1');
      expect(contest.creatorId, 'creator');
      expect(contest.title, '夕焼けコンテスト');
      expect(contest.description, '夕焼け写真を募集します');
      expect(contest.entryDeadline, entryDeadline);
      expect(contest.votingDeadline, votingDeadline);
      expect(contest.createdAt, createdAt);
      expect(contest.updatedAt, updatedAt);

      final map = contest.toMap();
      expect(map['creatorId'], contest.creatorId);
      expect(map['title'], contest.title);
      expect(map['description'], contest.description);
      expect((map['entryDeadline'] as Timestamp).toDate(), entryDeadline);
      expect((map['votingDeadline'] as Timestamp).toDate(), votingDeadline);
      expect((map['createdAt'] as Timestamp).toDate(), createdAt);
      expect((map['updatedAt'] as Timestamp).toDate(), updatedAt);
    });

    test('phaseAt returns entry before entry deadline', () {
      final contest = _contest();

      expect(
        contest.phaseAt(DateTime(2026, 9, 10, 11, 59)),
        ContestPhase.entry,
      );
    });

    test('phaseAt returns voting at entry deadline', () {
      final contest = _contest();

      expect(contest.phaseAt(DateTime(2026, 9, 10, 12)), ContestPhase.voting);
    });

    test('phaseAt returns voting before voting deadline', () {
      final contest = _contest();

      expect(
        contest.phaseAt(DateTime(2026, 9, 20, 11, 59)),
        ContestPhase.voting,
      );
    });

    test('phaseAt returns ended at voting deadline', () {
      final contest = _contest();

      expect(contest.phaseAt(DateTime(2026, 9, 20, 12)), ContestPhase.ended);
    });
  });
}

Contest _contest() {
  return Contest(
    id: 'contest-1',
    creatorId: 'creator',
    title: 'contest',
    description: '',
    entryDeadline: DateTime(2026, 9, 10, 12),
    votingDeadline: DateTime(2026, 9, 20, 12),
    createdAt: DateTime(2026, 9, 1),
    updatedAt: DateTime(2026, 9, 1),
  );
}
