import 'package:afterglow_app/models/post.dart';
import 'package:afterglow_app/services/auth_service.dart';
import 'package:afterglow_app/services/user_service.dart';
import 'package:afterglow_app/widgets/post_detail_view.dart';
import 'package:afterglow_app/widgets/post_widget.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:firebase_storage_mocks/firebase_storage_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 詳細の中身（[PostDetailView]）のふるまいは post_detail_page_test.dart で網羅する。
/// ここでは Dialog として体裁を整えて表示できることだけを確認する。

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

Widget _dialog(String viewerUid) {
  return MaterialApp(
    home: Scaffold(
      body: PostCardView(
        _post(),
        authService: _authServiceFor(viewerUid),
        userService: UserService(
          firestore: FakeFirebaseFirestore(),
          storage: MockFirebaseStorage(),
        ),
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

  testWidgets('shows the owner actions inside the dialog', (tester) async {
    await tester.pumpWidget(_dialog('user-1'));

    expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
    expect(find.byIcon(Icons.delete_outline), findsOneWidget);
  });
}
