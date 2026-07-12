import 'package:afterglow_app/models/post.dart';
import 'package:afterglow_app/services/user_service.dart';
import 'package:afterglow_app/widgets/post_card.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_storage_mocks/firebase_storage_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Post _post({
  List<String> imageUrls = const ['https://example.com/1.jpg'],
  List<String> tags = const ['桜'],
  int likeCount = 0,
  int commentCount = 0,
}) {
  return Post(
    id: 'post-1',
    userId: 'user-1',
    caption: 'sunset view',
    imageUrls: imageUrls,
    latitude: 35.0,
    longitude: 139.0,
    createdAt: DateTime(2026, 4, 18, 10, 0),
    tags: tags,
    likeCount: likeCount,
    commentCount: commentCount,
  );
}

/// 未初期化の Firebase に触れないよう、常にモックを注入した UserService を使う。
Future<UserService> _userServiceWith({String? username}) async {
  final firestore = FakeFirebaseFirestore();
  if (username != null) {
    await firestore.collection(UserService.usersCollection).doc('user-1').set({
      'username': username,
      'email': 'user1@example.com',
      'createdAt': Timestamp.fromDate(DateTime(2026, 1, 1)),
    });
  }
  return UserService(firestore: firestore, storage: MockFirebaseStorage());
}

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets('shows the caption, tags and counts', (tester) async {
    final userService = await _userServiceWith(username: 'ヨコチ');

    await tester.pumpWidget(
      _wrap(
        PostCard(
          _post(tags: const ['桜', '夜景'], likeCount: 4, commentCount: 2),
          userService: userService,
        ),
      ),
    );
    await tester.pump();

    expect(find.text('sunset view'), findsOneWidget);
    expect(find.text('ヨコチ'), findsOneWidget);
    expect(find.text('#桜'), findsOneWidget);
    expect(find.text('#夜景'), findsOneWidget);
    expect(find.text('4'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
  });

  testWidgets('falls back to a placeholder name when the author is unknown', (
    tester,
  ) async {
    final userService = await _userServiceWith();

    await tester.pumpWidget(_wrap(PostCard(_post(), userService: userService)));
    await tester.pump();

    expect(find.text('名無しさん'), findsOneWidget);
  });

  testWidgets('shows a placeholder icon when the post has no image', (
    tester,
  ) async {
    final userService = await _userServiceWith(username: 'ヨコチ');

    await tester.pumpWidget(
      _wrap(PostCard(_post(imageUrls: const []), userService: userService)),
    );
    await tester.pump();

    expect(find.byIcon(Icons.image_not_supported), findsOneWidget);
  });

  testWidgets('calls onTap when the card is tapped', (tester) async {
    final userService = await _userServiceWith(username: 'ヨコチ');
    var tapped = 0;

    await tester.pumpWidget(
      _wrap(PostCard(_post(), userService: userService, onTap: () => tapped++)),
    );
    await tester.pump();

    await tester.tap(find.byType(PostCard));
    await tester.pump();

    expect(tapped, 1);
  });
}
