import 'package:afterglow_app/models/notification.dart';
import 'package:afterglow_app/pages/notification_page.dart';
import 'package:afterglow_app/services/auth_service.dart';
import 'package:afterglow_app/services/notification_service.dart';
import 'package:afterglow_app/services/post_service.dart';
import 'package:afterglow_app/services/push_notification_service.dart';
import 'package:afterglow_app/services/user_service.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:firebase_storage_mocks/firebase_storage_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late FakeFirebaseFirestore firestore;

  setUp(() async {
    firestore = FakeFirebaseFirestore();
    await firestore.doc('users/actor').set({'username': 'たろう'});
    await firestore.doc('users/me/private/profile').set({
      'email': 'me@example.com',
      'emailNotification': true,
    });
  });

  Future<void> addNotification(
    String id, {
    required String type,
    required DateTime createdAt,
    bool isRead = false,
  }) {
    return firestore
        .collection(NotificationService.notificationsCollection)
        .doc(id)
        .set(
          AppNotification(
            id: id,
            recipientId: 'me',
            actorId: 'actor',
            type: type,
            sourceId: 'missing-post',
            isRead: isRead,
            createdAt: createdAt,
          ).toMap(),
        );
  }

  Widget page() {
    return MaterialApp(
      home: NotificationPage(
        authService: AuthService(
          auth: MockFirebaseAuth(signedIn: true, mockUser: MockUser(uid: 'me')),
          firestore: firestore,
        ),
        notificationService: NotificationService(firestore: firestore),
        userService: UserService(
          firestore: firestore,
          storage: MockFirebaseStorage(),
        ),
        postService: PostService(
          firestore: firestore,
          storage: MockFirebaseStorage(),
        ),
        pushNotificationService: PushNotificationService(firestore: firestore),
      ),
    );
  }

  testWidgets('shows notifications with the actor name', (tester) async {
    await addNotification(
      'n-1',
      type: AppNotification.typeReaction,
      createdAt: DateTime(2026, 10, 1),
    );
    await addNotification(
      'n-2',
      type: AppNotification.typeComment,
      createdAt: DateTime(2026, 10, 2),
      isRead: true,
    );

    await tester.pumpWidget(page());
    await tester.pumpAndSettle();

    expect(find.text('たろうさんがあなたの投稿にいいねしました'), findsOneWidget);
    expect(find.text('たろうさんがあなたの投稿にコメントしました'), findsOneWidget);
    expect(find.text('週次メール通知'), findsOneWidget);
  });

  testWidgets('shows an empty state without notifications', (tester) async {
    await tester.pumpWidget(page());
    await tester.pumpAndSettle();

    expect(find.text('通知はまだありません'), findsOneWidget);
  });

  testWidgets('tapping a notification marks it as read', (tester) async {
    await addNotification(
      'n-1',
      type: AppNotification.typeReaction,
      createdAt: DateTime(2026, 10, 1),
    );

    await tester.pumpWidget(page());
    await tester.pumpAndSettle();

    await tester.tap(find.text('たろうさんがあなたの投稿にいいねしました'));
    await tester.pumpAndSettle();

    final doc = await firestore
        .collection(NotificationService.notificationsCollection)
        .doc('n-1')
        .get();
    expect(doc.data()!['isRead'], isTrue);
    // 対象の投稿が存在しない場合は遷移せずに知らせる
    expect(find.text('対象の投稿は削除されています'), findsOneWidget);
  });

  testWidgets('email notification switch updates the setting', (tester) async {
    await tester.pumpWidget(page());
    await tester.pumpAndSettle();

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    final profile = await firestore.doc('users/me/private/profile').get();
    expect(profile.data()!['emailNotification'], isFalse);
  });
}
