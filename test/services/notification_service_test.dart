import 'package:afterglow_app/models/notification.dart';
import 'package:afterglow_app/services/notification_service.dart';
import 'package:afterglow_app/services/push_notification_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('NotificationService', () {
    late FakeFirebaseFirestore firestore;
    late NotificationService service;

    setUp(() {
      firestore = FakeFirebaseFirestore();
      service = NotificationService(firestore: firestore);
    });

    CollectionReference<Map<String, dynamic>> notificationsRef() =>
        firestore.collection(NotificationService.notificationsCollection);

    Future<void> addNotification(
      String id, {
      required String recipientId,
      required DateTime createdAt,
      bool isRead = false,
    }) {
      return notificationsRef()
          .doc(id)
          .set(
            AppNotification(
              id: id,
              recipientId: recipientId,
              actorId: 'actor',
              type: AppNotification.typeReaction,
              sourceId: 'post-1',
              isRead: isRead,
              createdAt: createdAt,
            ).toMap(),
          );
    }

    test(
      'getNotifications returns only the recipient notifications, newest first',
      () async {
        await addNotification(
          'old',
          recipientId: 'user-1',
          createdAt: DateTime(2026, 10, 1),
        );
        await addNotification(
          'new',
          recipientId: 'user-1',
          createdAt: DateTime(2026, 10, 3),
        );
        await addNotification(
          'others',
          recipientId: 'user-2',
          createdAt: DateTime(2026, 10, 2),
        );

        final notifications = await service.getNotifications('user-1').first;

        expect(notifications.map((n) => n.id), ['new', 'old']);
      },
    );

    test('watchUnreadCount counts only unread notifications', () async {
      await addNotification(
        'unread',
        recipientId: 'user-1',
        createdAt: DateTime(2026, 10, 1),
      );
      await addNotification(
        'read',
        recipientId: 'user-1',
        createdAt: DateTime(2026, 10, 2),
        isRead: true,
      );
      await addNotification(
        'others',
        recipientId: 'user-2',
        createdAt: DateTime(2026, 10, 2),
      );

      expect(await service.watchUnreadCount('user-1').first, 1);
    });

    test('markAsRead sets isRead to true', () async {
      await addNotification(
        'n-1',
        recipientId: 'user-1',
        createdAt: DateTime(2026, 10, 1),
      );

      await service.markAsRead('n-1');

      final doc = await notificationsRef().doc('n-1').get();
      expect(doc.data()!['isRead'], isTrue);
    });

    test(
      'markAllAsRead marks every unread notification of the recipient',
      () async {
        await addNotification(
          'a',
          recipientId: 'user-1',
          createdAt: DateTime(2026, 10, 1),
        );
        await addNotification(
          'b',
          recipientId: 'user-1',
          createdAt: DateTime(2026, 10, 2),
        );
        await addNotification(
          'others',
          recipientId: 'user-2',
          createdAt: DateTime(2026, 10, 2),
        );

        await service.markAllAsRead('user-1');

        expect(await service.watchUnreadCount('user-1').first, 0);
        expect(await service.watchUnreadCount('user-2').first, 1);
      },
    );

    test('email notification defaults to true and can be toggled', () async {
      expect(await service.watchEmailNotification('user-1').first, isTrue);

      await firestore.doc('users/user-1/private/profile').set({
        'email': 'user@example.com',
        'emailNotification': true,
      });
      await service.setEmailNotification('user-1', false);

      expect(await service.watchEmailNotification('user-1').first, isFalse);
      final profile = await firestore.doc('users/user-1/private/profile').get();
      // メールアドレス等の既存フィールドは保持する
      expect(profile.data()!['email'], 'user@example.com');
    });
  });

  group('PushNotificationService', () {
    test('saveToken stores tokens without duplicates', () async {
      final firestore = FakeFirebaseFirestore();
      final service = PushNotificationService(firestore: firestore);

      await service.saveToken('user-1', 'token-a');
      await service.saveToken('user-1', 'token-a');
      await service.saveToken('user-1', 'token-b');

      final doc = await firestore
          .doc(
            '${PushNotificationService.usersCollection}/user-1/'
            '${PushNotificationService.privateMessagingDoc}',
          )
          .get();
      expect(doc.data()!['tokens'], ['token-a', 'token-b']);
    });
  });
}
