import 'package:cloud_firestore/cloud_firestore.dart';

/// メンバーが参加を表明できる撮影会などのイベント（PS_06 / §3.7）。
/// `events/{eventId}` に保存される。イミュータブル。
class Event {
  const Event({
    required this.id,
    required this.organizerId,
    required this.title,
    required this.description,
    required this.locationName,
    required this.startAt,
    required this.createdAt,
    required this.updatedAt,
    this.latitude,
    this.longitude,
    this.endAt,
  });

  final String id;

  /// 主催者の UID。作成・更新できるのは主催者のみ（§7.2 / PS_08 系）。
  final String organizerId;

  final String title;

  /// イベントの詳細。欠損時は空文字。
  final String description;

  /// 集合場所名。欠損時は空文字。
  final String locationName;

  /// 集合場所の緯度・経度。地図ミニプレビュー（§5.7）に使う。
  /// 場所を地図上で指定しなかった場合は両方 null。
  final double? latitude;
  final double? longitude;

  final DateTime startAt;

  /// 終了日時。未設定なら null。
  final DateTime? endAt;

  final DateTime createdAt;
  final DateTime updatedAt;

  /// 緯度・経度が揃っている場合のみ地図ミニプレビューを表示できる。
  bool get hasLocation => latitude != null && longitude != null;

  factory Event.fromSnapshot(String id, Map<String, dynamic> document) {
    final createdAt =
        (document['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
    return Event(
      id: id,
      organizerId: document['organizerId'] ?? '',
      title: document['title'] ?? '',
      description: document['description'] ?? '',
      locationName: document['locationName'] ?? '',
      latitude: (document['latitude'] as num?)?.toDouble(),
      longitude: (document['longitude'] as num?)?.toDouble(),
      startAt: (document['startAt'] as Timestamp?)?.toDate() ?? createdAt,
      endAt: (document['endAt'] as Timestamp?)?.toDate(),
      createdAt: createdAt,
      // 旧データには updatedAt が無いことがあるため createdAt にフォールバックする。
      updatedAt: (document['updatedAt'] as Timestamp?)?.toDate() ?? createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'organizerId': organizerId,
      'title': title,
      'description': description,
      'locationName': locationName,
      'latitude': latitude,
      'longitude': longitude,
      'startAt': Timestamp.fromDate(startAt),
      'endAt': endAt == null ? null : Timestamp.fromDate(endAt!),
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }
}

/// イベントへの参加表明（PS_06 / §3.8）。
/// `events/{eventId}/participants/{userId}` に保存され、ドキュメント ID は
/// 参加者の UID と同一。ドキュメントの有無がそのまま参加状態を表す。
class EventParticipant {
  const EventParticipant({
    required this.userId,
    required this.joinedAt,
    this.comment,
  });

  /// 参加者の UID。ドキュメント ID と同一。
  final String userId;

  /// 参加コメント（任意）。未入力なら null。
  final String? comment;

  final DateTime joinedAt;

  factory EventParticipant.fromSnapshot(
    String id,
    Map<String, dynamic> document,
  ) {
    return EventParticipant(
      // userId はドキュメント ID を正とし、欠損データでも破綻させない。
      userId: document['userId'] ?? id,
      comment: document['comment'],
      joinedAt:
          (document['joinedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'comment': comment,
      'joinedAt': Timestamp.fromDate(joinedAt),
    };
  }
}
