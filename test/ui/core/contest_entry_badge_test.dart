import 'package:afterglow_app/data/models/contest.dart';
import 'package:afterglow_app/app/dependencies.dart';
import 'package:afterglow_app/ui/core/widgets/contest_entry_badge.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_storage_mocks/firebase_storage_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/dependencies.dart';

void main() {
  for (final phase in ContestPhase.values) {
    testWidgets('shows the contest title and status in $phase', (tester) async {
      final firestore = FakeFirebaseFirestore();
      final now = DateTime.now();
      final contest = Contest(
        id: 'contest-1',
        creatorId: 'creator',
        title: '秋の写真コンテスト',
        description: '',
        entryDeadline: phase == ContestPhase.entry
            ? now.add(const Duration(days: 1))
            : now.subtract(const Duration(days: 1)),
        votingDeadline: phase == ContestPhase.ended
            ? now.subtract(const Duration(hours: 1))
            : now.add(const Duration(days: 2)),
        createdAt: now,
        updatedAt: now,
      );
      final ref = firestore.collection('contests').doc(contest.id);
      await ref.set(contest.toMap());
      await tester.pumpWidget(
        withDependencies(
          AppDependencies(firestore: firestore, storage: MockFirebaseStorage()),
          MaterialApp(
            home: Scaffold(
              body: ContestEntryBadge(contestId: contest.id, voteCount: 3),
            ),
          ),
        ),
      );
      await tester.pump();
      final status = phase == ContestPhase.ended ? '応募作品' : '参加中';
      expect(find.text('秋の写真コンテスト$status・3票'), findsOneWidget);

      // 締切の変更と削除も、開いている画面へ反映する。
      await ref.update({
        'entryDeadline': contest.toMap()['createdAt'],
        'votingDeadline': contest.toMap()['createdAt'],
      });
      await tester.pump();
      expect(find.text('秋の写真コンテスト応募作品・3票'), findsOneWidget);
      await ref.delete();
      await tester.pump();
      expect(find.text('コンテスト応募作品・3票'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
