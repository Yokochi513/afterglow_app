import 'package:afterglow_app/models/post.dart';
import 'package:afterglow_app/services/auth_service.dart';
import 'package:afterglow_app/services/reaction_service.dart';
import 'package:afterglow_app/widgets/reaction_bar.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Post _post({int likeCount = 0}) => Post(
  id: 'post-1',
  userId: 'author-1',
  caption: 'sunset view',
  imageUrls: const ['https://example.com/1.jpg'],
  latitude: 35.0,
  longitude: 139.0,
  createdAt: DateTime(2026, 4, 18, 10, 0),
  likeCount: likeCount,
);

void main() {
  late FakeFirebaseFirestore firestore;

  setUp(() async {
    firestore = FakeFirebaseFirestore();
    await firestore
        .collection(ReactionService.postsCollection)
        .doc('post-1')
        .set({'userId': 'author-1', 'caption': 'sunset view', 'likeCount': 0});
  });

  /// [signedIn] が false のときは未ログイン状態の AuthService を注入する。
  Widget buildBar({bool signedIn = true, bool compact = false}) {
    return MaterialApp(
      home: Scaffold(
        body: ReactionBar(
          post: _post(),
          compact: compact,
          authService: AuthService(
            auth: MockFirebaseAuth(
              signedIn: signedIn,
              mockUser: MockUser(uid: 'user-1'),
            ),
            firestore: firestore,
          ),
          reactionService: ReactionService(firestore: firestore),
        ),
      ),
    );
  }

  testWidgets('タップでいいねが付き、アイコンといいね数が即時反映される', (tester) async {
    await tester.pumpWidget(buildBar());
    await tester.pump();

    expect(find.byIcon(Icons.favorite_border), findsOneWidget);
    expect(find.text('0'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.favorite_border));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.favorite), findsOneWidget);
    expect(find.text('1'), findsOneWidget);

    final doc = await firestore
        .collection(ReactionService.postsCollection)
        .doc('post-1')
        .collection(ReactionService.reactionsCollection)
        .doc('user-1')
        .get();
    expect(doc.exists, isTrue);
  });

  testWidgets('もう一度タップするといいねが解除される', (tester) async {
    await tester.pumpWidget(buildBar());
    await tester.pump();

    await tester.tap(find.byIcon(Icons.favorite_border));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.favorite));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.favorite_border), findsOneWidget);
    expect(find.text('0'), findsOneWidget);
  });

  testWidgets('未ログインではボタンが無効になる', (tester) async {
    await tester.pumpWidget(buildBar(signedIn: false));
    await tester.pump();

    final button = tester.widget<IconButton>(find.byType(IconButton));
    expect(button.onPressed, isNull);
  });

  testWidgets('compact でもいいねをトグルできる', (tester) async {
    await tester.pumpWidget(buildBar(compact: true));
    await tester.pump();

    await tester.tap(find.byIcon(Icons.favorite_border));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.favorite), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
  });
}
