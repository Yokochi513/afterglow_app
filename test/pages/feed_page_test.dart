import 'package:afterglow_app/models/post.dart';
import 'package:afterglow_app/pages/feed_page.dart';
import 'package:afterglow_app/services/auth_service.dart';
import 'package:afterglow_app/services/post_service.dart';
import 'package:afterglow_app/services/reaction_service.dart';
import 'package:afterglow_app/services/user_service.dart';
import 'package:afterglow_app/widgets/post_card.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:firebase_storage_mocks/firebase_storage_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _seedPosts(
  FakeFirebaseFirestore firestore, {
  required int count,
}) async {
  for (var index = 0; index < count; index++) {
    await firestore
        .collection(PostService.postsCollection)
        .doc('post-$index')
        .set(<String, dynamic>{
          'userId': 'user-1',
          'caption': 'post $index',
          'imageUrls': <String>[],
          'latitude': 35.0,
          'longitude': 139.0,
          'createdAt': Timestamp.fromDate(DateTime(2026, 4, 18, 9, index)),
        });
  }
}

void main() {
  late FakeFirebaseFirestore firestore;
  late MockFirebaseStorage storage;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    storage = MockFirebaseStorage();
  });

  Widget buildFeed() {
    return MaterialApp(
      home: FeedPage(
        postService: PostService(firestore: firestore, storage: storage),
        userService: UserService(firestore: firestore, storage: storage),
        authService: AuthService(
          auth: MockFirebaseAuth(),
          firestore: firestore,
        ),
        reactionService: ReactionService(firestore: firestore),
      ),
    );
  }

  testWidgets('shows an empty state when there are no posts', (tester) async {
    await tester.pumpWidget(buildFeed());
    await tester.pump();

    expect(find.text('まだ投稿がありません'), findsOneWidget);
    expect(find.byType(PostCard), findsNothing);
  });

  testWidgets('lists posts newest first', (tester) async {
    await _seedPosts(firestore, count: 3);

    await tester.pumpWidget(buildFeed());
    await tester.pump();

    expect(find.byType(PostCard), findsNWidgets(3));

    final captions = tester
        .widgetList<PostCard>(find.byType(PostCard))
        .map((card) => card.post.caption)
        .toList();
    expect(captions, <String>['post 2', 'post 1', 'post 0']);
  });

  testWidgets('loads the next page when scrolled to the end', (tester) async {
    // 先頭ページ（20 件）を超える件数を用意し、追加読み込みを発火させる。
    await _seedPosts(firestore, count: 25);

    await tester.pumpWidget(buildFeed());
    await tester.pump();

    // ListView は遅延構築なので、先頭ページの最古の投稿（post 5）はまだ出ない。
    expect(find.text('post 24'), findsOneWidget);
    expect(find.text('post 5'), findsNothing);

    // 先頭ページの末端までスクロールすると次ページが読み込まれ、
    // 20 件目より古い post 4..0 が続けて表示される。
    for (var i = 0; i < 10; i++) {
      await tester.drag(find.byType(ListView), const Offset(0, -2000));
      await tester.pumpAndSettle();
    }

    expect(find.text('post 0'), findsOneWidget);

    final posts = tester
        .widgetList<PostCard>(find.byType(PostCard))
        .map((PostCard card) => card.post)
        .toList();
    // 先頭ページと追加ページで投稿が重複しない。
    expect(posts.map((Post post) => post.id).toSet(), hasLength(posts.length));
  });
}
