import 'package:cloud_firestore/cloud_firestore.dart';

enum ContestPhase { entry, voting, ended }

class Contest {
  const Contest({
    required this.id,
    required this.creatorId,
    required this.title,
    required this.description,
    required this.entryDeadline,
    required this.votingDeadline,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String creatorId;
  final String title;
  final String description;
  final DateTime entryDeadline;
  final DateTime votingDeadline;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// フェーズ判定の集約点。Firestore ルールも同じ境界条件で判定する。
  ContestPhase phaseAt(DateTime now) {
    if (now.isBefore(entryDeadline)) {
      return ContestPhase.entry;
    }
    if (now.isBefore(votingDeadline)) {
      return ContestPhase.voting;
    }
    return ContestPhase.ended;
  }

  ContestPhase get phase => phaseAt(DateTime.now());

  bool get isEntryOpen => phase == ContestPhase.entry;

  bool get isVotingOpen => phase == ContestPhase.voting;

  factory Contest.fromSnapshot(String id, Map<String, dynamic> document) {
    final createdAt =
        (document['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
    final entryDeadline =
        (document['entryDeadline'] as Timestamp?)?.toDate() ?? createdAt;
    return Contest(
      id: id,
      creatorId: document['creatorId'] ?? '',
      title: document['title'] ?? '',
      description: document['description'] ?? '',
      entryDeadline: entryDeadline,
      votingDeadline:
          (document['votingDeadline'] as Timestamp?)?.toDate() ?? entryDeadline,
      createdAt: createdAt,
      updatedAt: (document['updatedAt'] as Timestamp?)?.toDate() ?? createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'creatorId': creatorId,
      'title': title,
      'description': description,
      'entryDeadline': Timestamp.fromDate(entryDeadline),
      'votingDeadline': Timestamp.fromDate(votingDeadline),
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }
}
