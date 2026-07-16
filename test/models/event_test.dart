import 'package:afterglow_app/models/event.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Event.fromSnapshot', () {
    test('maps every field of a full document', () {
      final event = Event.fromSnapshot('e-1', {
        'organizerId': 'user-1',
        'title': '夏の撮影会',
        'description': '海で撮る',
        'locationName': '岡山駅 東口',
        'latitude': 34.669478,
        'longitude': 133.951104,
        'startAt': Timestamp.fromDate(DateTime(2026, 8, 1, 10)),
        'endAt': Timestamp.fromDate(DateTime(2026, 8, 1, 17)),
        'createdAt': Timestamp.fromDate(DateTime(2026, 7, 15, 12)),
        'updatedAt': Timestamp.fromDate(DateTime(2026, 7, 16, 9)),
      });

      expect(event.id, 'e-1');
      expect(event.organizerId, 'user-1');
      expect(event.title, '夏の撮影会');
      expect(event.description, '海で撮る');
      expect(event.locationName, '岡山駅 東口');
      expect(event.latitude, 34.669478);
      expect(event.longitude, 133.951104);
      expect(event.startAt, DateTime(2026, 8, 1, 10));
      expect(event.endAt, DateTime(2026, 8, 1, 17));
      expect(event.createdAt, DateTime(2026, 7, 15, 12));
      expect(event.updatedAt, DateTime(2026, 7, 16, 9));
      expect(event.hasLocation, isTrue);
    });

    test('falls back to defaults for a document with missing fields', () {
      final event = Event.fromSnapshot('e-1', const {});

      expect(event.organizerId, '');
      expect(event.title, '');
      expect(event.description, '');
      expect(event.locationName, '');
      expect(event.latitude, isNull);
      expect(event.longitude, isNull);
      expect(event.endAt, isNull);
      expect(event.hasLocation, isFalse);
      // startAt / updatedAt は createdAt にフォールバックする。
      expect(event.startAt, event.createdAt);
      expect(event.updatedAt, event.createdAt);
    });

    test('reads integer coordinates stored as num', () {
      final event = Event.fromSnapshot('e-1', const {
        'latitude': 34,
        'longitude': 133,
      });

      expect(event.latitude, 34.0);
      expect(event.longitude, 133.0);
    });

    test('hasLocation is false when only one coordinate is present', () {
      final event = Event.fromSnapshot('e-1', const {'latitude': 34.6});

      expect(event.hasLocation, isFalse);
    });
  });

  group('Event.toMap', () {
    Event event({double? latitude, double? longitude, DateTime? endAt}) {
      return Event(
        id: 'e-1',
        organizerId: 'user-1',
        title: '夏の撮影会',
        description: '海で撮る',
        locationName: '岡山駅 東口',
        latitude: latitude,
        longitude: longitude,
        startAt: DateTime(2026, 8, 1, 10),
        endAt: endAt,
        createdAt: DateTime(2026, 7, 15, 12),
        updatedAt: DateTime(2026, 7, 16, 9),
      );
    }

    test('writes every field and round-trips through fromSnapshot', () {
      final original = event(
        latitude: 34.669478,
        longitude: 133.951104,
        endAt: DateTime(2026, 8, 1, 17),
      );

      final restored = Event.fromSnapshot('e-1', original.toMap());

      expect(restored.organizerId, original.organizerId);
      expect(restored.title, original.title);
      expect(restored.description, original.description);
      expect(restored.locationName, original.locationName);
      expect(restored.latitude, original.latitude);
      expect(restored.longitude, original.longitude);
      expect(restored.startAt, original.startAt);
      expect(restored.endAt, original.endAt);
      expect(restored.createdAt, original.createdAt);
      expect(restored.updatedAt, original.updatedAt);
    });

    test('keeps optional fields null instead of dropping them', () {
      final map = event().toMap();

      expect(map.containsKey('latitude'), isTrue);
      expect(map['latitude'], isNull);
      expect(map['longitude'], isNull);
      expect(map['endAt'], isNull);
    });

    test('does not include the document id', () {
      expect(event().toMap().containsKey('id'), isFalse);
    });
  });

  group('EventParticipant', () {
    test('maps a full document', () {
      final participant = EventParticipant.fromSnapshot('user-2', {
        'userId': 'user-2',
        'comment': '現地で合流します',
        'joinedAt': Timestamp.fromDate(DateTime(2026, 7, 16, 9)),
      });

      expect(participant.userId, 'user-2');
      expect(participant.comment, '現地で合流します');
      expect(participant.joinedAt, DateTime(2026, 7, 16, 9));
    });

    test('falls back to the document id when userId is missing', () {
      final participant = EventParticipant.fromSnapshot('user-2', const {});

      expect(participant.userId, 'user-2');
      expect(participant.comment, isNull);
    });

    test('round-trips through toMap', () {
      final original = EventParticipant(
        userId: 'user-2',
        comment: '現地で合流します',
        joinedAt: DateTime(2026, 7, 16, 9),
      );

      final restored = EventParticipant.fromSnapshot(
        'user-2',
        original.toMap(),
      );

      expect(restored.userId, original.userId);
      expect(restored.comment, original.comment);
      expect(restored.joinedAt, original.joinedAt);
    });

    test('keeps a null comment in toMap instead of dropping it', () {
      final map = EventParticipant(
        userId: 'user-2',
        joinedAt: DateTime(2026, 7, 16, 9),
      ).toMap();

      expect(map.containsKey('comment'), isTrue);
      expect(map['comment'], isNull);
    });
  });
}
