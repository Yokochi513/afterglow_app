import 'package:afterglow_app/models/post.dart';
import 'package:afterglow_app/widgets/post_widget.dart';
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

void main() {
  testWidgets('shows the caption text', (tester) async {
    await tester.pumpWidget(_wrap(PostCardView(_post())));

    expect(find.text('sunset view'), findsOneWidget);
  });

  testWidgets('caption field is read only', (tester) async {
    await tester.pumpWidget(_wrap(PostCardView(_post())));

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
        ),
      ),
    );

    expect(find.byIcon(Icons.chevron_left), findsOneWidget);
    expect(find.byIcon(Icons.chevron_right), findsOneWidget);
  });

  testWidgets('hides navigation arrows for a single image', (tester) async {
    await tester.pumpWidget(_wrap(PostCardView(_post())));

    expect(find.byIcon(Icons.chevron_left), findsNothing);
    expect(find.byIcon(Icons.chevron_right), findsNothing);
    expect(find.text('1 / 1'), findsOneWidget);
  });
}
