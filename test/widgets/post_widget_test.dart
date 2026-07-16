import 'package:afterglow_app/models/post.dart';
import 'package:afterglow_app/services/auth_service.dart';
import 'package:afterglow_app/services/user_service.dart';
import 'package:afterglow_app/widgets/post_detail_view.dart';
import 'package:afterglow_app/widgets/post_widget.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:firebase_storage_mocks/firebase_storage_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';

/// 詳細の中身（[PostDetailView]）のふるまいは post_detail_page_test.dart で網羅する。
/// ここでは Dialog としての体裁と、地図向けサマリー（[PostViewMode.summary]）
/// としての出し分けを確認する。

Post _post() {
  return Post(
    id: 'post-1',
    userId: 'user-1',
    caption: 'sunset view',
    imageUrls: const ['https://example.com/1.jpg'],
    latitude: 35.0,
    longitude: 139.0,
    createdAt: DateTime(2026, 4, 18, 10, 0),
  );
}

AuthService _authServiceFor(String uid) {
  return AuthService(
    auth: MockFirebaseAuth(signedIn: true, mockUser: MockUser(uid: uid)),
    firestore: FakeFirebaseFirestore(),
  );
}

Widget _dialog(String viewerUid, {VoidCallback? onOpenDetail}) {
  return MaterialApp(
    home: Scaffold(
      body: PostCardView(
        _post(),
        authService: _authServiceFor(viewerUid),
        userService: UserService(
          firestore: FakeFirebaseFirestore(),
          storage: MockFirebaseStorage(),
        ),
        reactionBar: const Text('reaction-bar'),
        commentSection: const Text('comment-section'),
        onOpenDetail: onOpenDetail,
      ),
    ),
  );
}

void main() {
  testWidgets('shows the post detail inside a dialog', (tester) async {
    await tester.pumpWidget(_dialog('viewer'));

    expect(find.byType(Dialog), findsOneWidget);
    expect(find.byType(PostDetailView), findsOneWidget);
    expect(find.text('sunset view'), findsOneWidget);
  });

  testWidgets('サマリーはいいねとコメントを出す', (tester) async {
    await tester.pumpWidget(_dialog('viewer'));

    expect(find.text('reaction-bar'), findsOneWidget);
    expect(find.text('comment-section'), findsOneWidget);
  });

  testWidgets('サマリーは地図ミニプレビューを出さない', (tester) async {
    await tester.pumpWidget(_dialog('viewer'));

    expect(find.byType(FlutterMap), findsNothing);
  });

  testWidgets('サマリーは自投稿でも編集・削除を出さない', (tester) async {
    await tester.pumpWidget(_dialog('user-1'));

    expect(find.byIcon(Icons.edit_outlined), findsNothing);
    expect(find.byIcon(Icons.delete_outline), findsNothing);
  });

  testWidgets('「詳細を見る」で詳細ページへの導線を出す', (tester) async {
    var opened = false;
    await tester.pumpWidget(
      _dialog('viewer', onOpenDetail: () => opened = true),
    );

    await tester.tap(find.text('詳細を見る'));
    expect(opened, isTrue);
  });

  testWidgets('onOpenDetail 未指定なら導線を出さない', (tester) async {
    await tester.pumpWidget(_dialog('viewer'));

    expect(find.text('詳細を見る'), findsNothing);
  });
}
