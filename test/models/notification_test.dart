import 'package:afterglow_app/models/notification.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppNotification', () {
    test('fromSnapshot reads all fields', () {
      final notification = AppNotification.fromSnapshot('n-1', {
        'recipientId': 'user-1',
        'actorId': 'user-2',
        'type': AppNotification.typeComment,
        'sourceId': 'post-1',
        'isRead': true,
        'createdAt': Timestamp.fromDate(DateTime(2026, 10, 1, 12)),
      });

      expect(notification.id, 'n-1');
      expect(notification.recipientId, 'user-1');
      expect(notification.actorId, 'user-2');
      expect(notification.type, AppNotification.typeComment);
      expect(notification.sourceId, 'post-1');
      expect(notification.isRead, isTrue);
      expect(notification.createdAt, DateTime(2026, 10, 1, 12));
      expect(notification.targetsPost, isTrue);
      expect(notification.targetsEvent, isFalse);
    });

    test('fromSnapshot falls back to defaults for missing fields', () {
      final notification = AppNotification.fromSnapshot('n-2', {});

      expect(notification.recipientId, '');
      expect(notification.actorId, '');
      expect(notification.type, '');
      expect(notification.sourceId, '');
      expect(notification.isRead, isFalse);
      expect(notification.targetsPost, isFalse);
      expect(notification.targetsEvent, isFalse);
    });

    test('event_update targets an event', () {
      final notification = AppNotification.fromSnapshot('n-3', {
        'type': AppNotification.typeEventUpdate,
      });

      expect(notification.targetsEvent, isTrue);
      expect(notification.targetsPost, isFalse);
    });

    test('toMap round-trips through fromSnapshot', () {
      final original = AppNotification(
        id: 'n-4',
        recipientId: 'user-1',
        actorId: 'user-2',
        type: AppNotification.typeReaction,
        sourceId: 'post-9',
        createdAt: DateTime(2026, 10, 2, 8, 30),
      );

      final restored = AppNotification.fromSnapshot('n-4', original.toMap());

      expect(restored.recipientId, original.recipientId);
      expect(restored.actorId, original.actorId);
      expect(restored.type, original.type);
      expect(restored.sourceId, original.sourceId);
      expect(restored.isRead, isFalse);
      expect(restored.createdAt, original.createdAt);
    });
  });
}
