import 'package:afterglow_app/models/post.dart';
import 'package:afterglow_app/services/auth_service.dart';
import 'package:afterglow_app/services/reaction_service.dart';
import 'package:afterglow_app/services/user_service.dart';
import 'package:afterglow_app/widgets/post_card.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
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

/// 未初期化の Firebase に触れないよう、常にモックを注入したサービスを使う。
/// [username] を渡すと投稿者の users ドキュメントを、[reactionCount] を渡すと
/// その数だけ posts/post-1/reactions のドキュメントを用意する。
Future<FakeFirebaseFirestore> _firestoreWith({
  String? username,
  int reactionCount = 0,
}) async {
  final firestore = FakeFirebaseFirestore();

  if (username != null) {
    await firestore.collection(UserService.usersCollection).doc('user-1').set({
      'username': username,
      'email': 'user1@example.com',
      'createdAt': Timestamp.fromDate(DateTime(2026, 1, 1)),
    });
  }

  for (var index = 0; index < reactionCount; index++) {
    await firestore
        .collection(ReactionService.postsCollection)
        .doc('post-1')
        .collection(ReactionService.reactionsCollection)
        .doc('liker-$index')
        .set({
          'userId': 'liker-$index',
          'type': ReactionService.likeType,
          'createdAt': Timestamp.fromDate(DateTime(2026, 4, 18)),
        });
  }

  return firestore;
}

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

Widget _card(
  Post post,
  FakeFirebaseFirestore firestore, {
  VoidCallback? onTap,
}) {
  return PostCard(
    post,
    onTap: onTap,
    userService: UserService(
      firestore: firestore,
      storage: MockFirebaseStorage(),
    ),
    authService: AuthService(auth: MockFirebaseAuth(), firestore: firestore),
    reactionService: ReactionService(firestore: firestore),
  );
}

void main() {
  testWidgets('shows the caption, tags and counts', (tester) async {
    final firestore = await _firestoreWith(username: 'ヨコチ', reactionCount: 4);

    await tester.pumpWidget(
      _wrap(
        _card(
          _post(tags: const ['桜', '夜景'], likeCount: 4, commentCount: 2),
          firestore,
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
    final firestore = await _firestoreWith();

    await tester.pumpWidget(_wrap(_card(_post(), firestore)));
    await tester.pump();

    expect(find.text('名無しさん'), findsOneWidget);
  });

  testWidgets('shows a placeholder icon when the post has no image', (
    tester,
  ) async {
    final firestore = await _firestoreWith(username: 'ヨコチ');

    await tester.pumpWidget(
      _wrap(_card(_post(imageUrls: const []), firestore)),
    );
    await tester.pump();

    expect(find.byIcon(Icons.image_not_supported), findsOneWidget);
  });

  testWidgets('calls onTap when the card is tapped', (tester) async {
    final firestore = await _firestoreWith(username: 'ヨコチ');
    var tapped = 0;

    await tester.pumpWidget(
      _wrap(_card(_post(), firestore, onTap: () => tapped++)),
    );
    await tester.pump();

    await tester.tap(find.byType(PostCard));
    await tester.pump();

    expect(tapped, 1);
  });
}
