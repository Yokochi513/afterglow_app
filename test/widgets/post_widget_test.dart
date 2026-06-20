import 'package:afterglow_app/models/post.dart';
import 'package:afterglow_app/services/auth_service.dart';
import 'package:afterglow_app/services/post_service.dart';
import 'package:afterglow_app/widgets/post_widget.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:firebase_storage_mocks/firebase_storage_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Post _post({List<String> imageUrls = const ['https://example.com/1.jpg']}) {
  return Post(
    id: 'post-1',
    userId: 'user-1',
    caption: 'sunset view',
    imageUrls: imageUrls,
    latitude: 35.0,
    longitude: 139.0,
    createdAt: DateTime(2026, 4, 18, 10, 0),
  );
}

Widget _wrap(Widget child) {
  return MaterialApp(home: Scaffold(body: child));
}

AuthService _authServiceFor(String? uid) {
  final auth = uid == null
      ? MockFirebaseAuth()
      : MockFirebaseAuth(signedIn: true, mockUser: MockUser(uid: uid));
  return AuthService(auth: auth, firestore: FakeFirebaseFirestore());
}

void main() {
  // 表示系テストは所有者でない閲覧者として描画し、削除ボタンを介在させない。
  final viewerAuthService = _authServiceFor('viewer');

  testWidgets('shows the caption text', (tester) async {
    await tester.pumpWidget(
      _wrap(PostCardView(_post(), authService: viewerAuthService)),
    );

    expect(find.text('sunset view'), findsOneWidget);
  });

  testWidgets('caption field is read only', (tester) async {
    await tester.pumpWidget(
      _wrap(PostCardView(_post(), authService: viewerAuthService)),
    );

    final textField = tester.widget<TextField>(find.byType(TextField));
    expect(textField.readOnly, isTrue);
  });

  testWidgets('shows the image counter for the first image', (tester) async {
    await tester.pumpWidget(
      _wrap(
        PostCardView(
          _post(
            imageUrls: const [
              'https://example.com/1.jpg',
              'https://example.com/2.jpg',
            ],
          ),
          authService: viewerAuthService,
        ),
      ),
    );

    expect(find.text('1 / 2'), findsOneWidget);
  });

  testWidgets('shows navigation arrows when there are multiple images', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        PostCardView(
          _post(
            imageUrls: const [
              'https://example.com/1.jpg',
              'https://example.com/2.jpg',
            ],
          ),
          authService: viewerAuthService,
        ),
      ),
    );

    expect(find.byIcon(Icons.chevron_left), findsOneWidget);
    expect(find.byIcon(Icons.chevron_right), findsOneWidget);
  });

  testWidgets('hides navigation arrows for a single image', (tester) async {
    await tester.pumpWidget(
      _wrap(PostCardView(_post(), authService: viewerAuthService)),
    );

    expect(find.byIcon(Icons.chevron_left), findsNothing);
    expect(find.byIcon(Icons.chevron_right), findsNothing);
    expect(find.text('1 / 1'), findsOneWidget);
  });

  testWidgets('shows the delete button for the post owner', (tester) async {
    await tester.pumpWidget(
      _wrap(PostCardView(_post(), authService: _authServiceFor('user-1'))),
    );

    expect(find.byIcon(Icons.delete_outline), findsOneWidget);
  });

  testWidgets('hides the delete button for non-owners', (tester) async {
    await tester.pumpWidget(
      _wrap(
        PostCardView(_post(), authService: _authServiceFor('another-user')),
      ),
    );

    expect(find.byIcon(Icons.delete_outline), findsNothing);
  });

  testWidgets('hides the delete button when signed out', (tester) async {
    await tester.pumpWidget(
      _wrap(PostCardView(_post(), authService: _authServiceFor(null))),
    );

    expect(find.byIcon(Icons.delete_outline), findsNothing);
  });

  testWidgets('deletes the post after confirmation', (tester) async {
    final firestore = FakeFirebaseFirestore();
    await firestore.collection(PostService.postsCollection).doc('post-1').set({
      'userId': 'user-1',
      'caption': 'sunset view',
      'imageUrls': const <String>[],
      'latitude': 35.0,
      'longitude': 139.0,
    });
    final postService = PostService(
      firestore: firestore,
      storage: MockFirebaseStorage(),
    );

    await tester.pumpWidget(
      _wrap(
        PostCardView(
          _post(imageUrls: const []),
          authService: _authServiceFor('user-1'),
          postService: postService,
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();

    // 確認ダイアログの「削除」をタップ
    await tester.tap(find.widgetWithText(TextButton, '削除'));
    await tester.pumpAndSettle();

    final snapshot = await firestore
        .collection(PostService.postsCollection)
        .doc('post-1')
        .get();
    expect(snapshot.exists, isFalse);
  });

  testWidgets('keeps the post when deletion is cancelled', (tester) async {
    final firestore = FakeFirebaseFirestore();
    await firestore.collection(PostService.postsCollection).doc('post-1').set({
      'userId': 'user-1',
      'caption': 'sunset view',
      'imageUrls': const <String>[],
      'latitude': 35.0,
      'longitude': 139.0,
    });
    final postService = PostService(
      firestore: firestore,
      storage: MockFirebaseStorage(),
    );

    await tester.pumpWidget(
      _wrap(
        PostCardView(
          _post(imageUrls: const []),
          authService: _authServiceFor('user-1'),
          postService: postService,
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(TextButton, 'キャンセル'));
    await tester.pumpAndSettle();

    final snapshot = await firestore
        .collection(PostService.postsCollection)
        .doc('post-1')
        .get();
    expect(snapshot.exists, isTrue);
  });
}
