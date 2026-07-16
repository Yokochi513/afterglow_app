import 'package:afterglow_app/models/event.dart';
import 'package:afterglow_app/services/event_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('EventService', () {
    late FakeFirebaseFirestore firestore;
    late EventService service;

    setUp(() {
      firestore = FakeFirebaseFirestore();
      service = EventService(firestore: firestore);
    });

    CollectionReference<Map<String, dynamic>> eventsRef() =>
        firestore.collection(EventService.eventsCollection);

    CollectionReference<Map<String, dynamic>> participantsRef(String eventId) =>
        eventsRef()
            .doc(eventId)
            .collection(EventService.participantsCollection);

    Event event({
      String id = '',
      String organizerId = 'user-1',
      String title = '夏の撮影会',
      String description = '',
      String locationName = '',
      double? latitude,
      double? longitude,
      DateTime? startAt,
      DateTime? endAt,
      DateTime? createdAt,
      DateTime? updatedAt,
    }) {
      final created = createdAt ?? DateTime(2026, 7, 15, 12);
      return Event(
        id: id,
        organizerId: organizerId,
        title: title,
        description: description,
        locationName: locationName,
        latitude: latitude,
        longitude: longitude,
        startAt: startAt ?? DateTime(2026, 8, 1, 10),
        endAt: endAt,
        createdAt: created,
        updatedAt: updatedAt ?? created,
      );
    }

    test('createEvent stores every field of the event', () async {
      final created = await service.createEvent(
        event(
          id: 'e-1',
          description: '海で撮る',
          locationName: '岡山駅 東口',
          latitude: 34.6,
          longitude: 133.9,
          endAt: DateTime(2026, 8, 1, 17),
        ),
      );

      expect(created, isTrue);

      final data = (await eventsRef().doc('e-1').get()).data()!;
      expect(data['organizerId'], 'user-1');
      expect(data['title'], '夏の撮影会');
      expect(data['description'], '海で撮る');
      expect(data['locationName'], '岡山駅 東口');
      expect(data['latitude'], 34.6);
      expect(data['longitude'], 133.9);
      expect(data['startAt'], isA<Timestamp>());
      expect(data['endAt'], isA<Timestamp>());
      expect(data['createdAt'], isA<Timestamp>());
      expect(data['updatedAt'], isA<Timestamp>());
    });

    test('createEvent lets Firestore assign an id when it is empty', () async {
      expect(await service.createEvent(event()), isTrue);

      final docs = (await eventsRef().get()).docs;
      expect(docs, hasLength(1));
      expect(docs.single.id, isNotEmpty);
    });

    test('getEvents returns every event in ascending startAt order', () async {
      await service.createEvent(
        event(id: 'e-late', title: '後', startAt: DateTime(2026, 9, 1, 10)),
      );
      await service.createEvent(
        event(
          id: 'e-early',
          organizerId: 'user-2',
          title: '先',
          startAt: DateTime(2026, 8, 1, 10),
        ),
      );

      final events = await service.getEvents().first;

      // 表示範囲は「全体」なので、他ユーザー(user-2)主催のイベントも含まれる。
      expect(events.map((e) => e.id).toList(), ['e-early', 'e-late']);
    });

    test('watchEvent emits the event and null when it is missing', () async {
      await service.createEvent(event(id: 'e-1', title: '春の撮影会'));

      expect((await service.watchEvent('e-1').first)!.title, '春の撮影会');
      expect(await service.watchEvent('missing').first, isNull);
    });

    test('updateEvent rewrites the editable fields', () async {
      await service.createEvent(event(id: 'e-1'));
      final stored = (await service.watchEvent('e-1').first)!;

      final result = await service.updateEvent(
        Event(
          id: stored.id,
          organizerId: stored.organizerId,
          title: '編集後',
          description: '詳細も更新',
          locationName: '後楽園',
          latitude: 34.67,
          longitude: 133.93,
          startAt: DateTime(2026, 8, 2, 9),
          endAt: DateTime(2026, 8, 2, 12),
          createdAt: stored.createdAt,
          updatedAt: DateTime(2026, 7, 20),
        ),
      );
      expect(result, isTrue);

      final updated = (await service.watchEvent('e-1').first)!;
      expect(updated.title, '編集後');
      expect(updated.description, '詳細も更新');
      expect(updated.locationName, '後楽園');
      expect(updated.latitude, 34.67);
      expect(updated.startAt, DateTime(2026, 8, 2, 9));
      expect(updated.endAt, DateTime(2026, 8, 2, 12));
    });

    test('updateEvent keeps organizerId and createdAt untouched', () async {
      await service.createEvent(
        event(id: 'e-1', createdAt: DateTime(2026, 7, 15, 12)),
      );

      // 主催者・作成日時を詐称した Event を渡しても、保存済みの値を保つ。
      await service.updateEvent(
        event(
          id: 'e-1',
          organizerId: 'attacker',
          title: '編集後',
          createdAt: DateTime(2020),
        ),
      );

      final updated = (await service.watchEvent('e-1').first)!;
      expect(updated.title, '編集後');
      expect(updated.organizerId, 'user-1');
      expect(updated.createdAt, DateTime(2026, 7, 15, 12));
    });

    test('updateEvent stamps updatedAt at write time', () async {
      await service.createEvent(
        event(id: 'e-1', updatedAt: DateTime(2026, 7, 15, 12)),
      );

      final before = DateTime.now();
      await service.updateEvent(event(id: 'e-1', title: '編集後'));

      final updated = (await service.watchEvent('e-1').first)!;
      expect(
        updated.updatedAt.isBefore(before),
        isFalse,
        reason: 'updatedAt は渡された値ではなく書き込み時刻で打ち直される',
      );
    });

    test('toggleParticipation creates the participant document', () async {
      await service.createEvent(event(id: 'e-1'));

      await service.toggleParticipation('e-1', 'user-2', '現地で合流します');

      final data = (await participantsRef('e-1').doc('user-2').get()).data()!;
      expect(data['userId'], 'user-2');
      expect(data['comment'], '現地で合流します');
      expect(data['joinedAt'], isA<Timestamp>());
    });

    test('toggleParticipation removes it on the second call', () async {
      await service.createEvent(event(id: 'e-1'));

      await service.toggleParticipation('e-1', 'user-2', null);
      expect((await participantsRef('e-1').doc('user-2').get()).exists, isTrue);

      await service.toggleParticipation('e-1', 'user-2', null);
      expect(
        (await participantsRef('e-1').doc('user-2').get()).exists,
        isFalse,
      );
    });

    test('toggleParticipation only affects the given user', () async {
      await service.createEvent(event(id: 'e-1'));

      await service.toggleParticipation('e-1', 'user-2', null);
      await service.toggleParticipation('e-1', 'user-3', null);
      await service.toggleParticipation('e-1', 'user-2', null);

      expect(
        (await participantsRef('e-1').doc('user-2').get()).exists,
        isFalse,
      );
      expect((await participantsRef('e-1').doc('user-3').get()).exists, isTrue);
    });

    test('getParticipants is sorted by joinedAt ascending', () async {
      await service.createEvent(event(id: 'e-1'));

      // joinedAt は書き込み時刻のため、順序を固定するために直接書き込む。
      await participantsRef('e-1')
          .doc('user-3')
          .set(
            EventParticipant(
              userId: 'user-3',
              joinedAt: DateTime(2026, 7, 16),
              comment: '後から参加',
            ).toMap(),
          );
      await participantsRef('e-1')
          .doc('user-2')
          .set(
            EventParticipant(
              userId: 'user-2',
              joinedAt: DateTime(2026, 7, 15),
            ).toMap(),
          );

      final participants = await service.getParticipants('e-1').first;

      expect(participants.map((p) => p.userId).toList(), ['user-2', 'user-3']);
      expect(participants.first.comment, isNull);
      expect(participants.last.comment, '後から参加');
    });

    test('watchIsParticipating tracks the participation state', () async {
      await service.createEvent(event(id: 'e-1'));

      expect(
        await service.watchIsParticipating('e-1', 'user-2').first,
        isFalse,
      );

      await service.toggleParticipation('e-1', 'user-2', null);
      expect(await service.watchIsParticipating('e-1', 'user-2').first, isTrue);
    });

    test('isOrganizedBy is true only for the organizer uid', () {
      final target = event(id: 'e-1');

      expect(service.isOrganizedBy(target, 'user-1'), isTrue);
      expect(service.isOrganizedBy(target, 'user-2'), isFalse);
      expect(service.isOrganizedBy(target, null), isFalse);
    });
  });
}
