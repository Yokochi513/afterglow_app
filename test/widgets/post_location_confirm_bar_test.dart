import 'package:afterglow_app/widgets/post_location_confirm_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap({
  required VoidCallback onConfirm,
  required VoidCallback onCancel,
}) {
  return MaterialApp(
    home: Scaffold(
      body: PostLocationConfirmBar(onConfirm: onConfirm, onCancel: onCancel),
    ),
  );
}

void main() {
  group('PostLocationConfirmBar', () {
    testWidgets('案内文と操作ボタンを表示する', (tester) async {
      await tester.pumpWidget(_wrap(onConfirm: () {}, onCancel: () {}));

      expect(find.text('この場所に投稿しますか？'), findsOneWidget);
      expect(find.text('地図をタップすると位置を選び直せます'), findsOneWidget);
      expect(find.text('ここに投稿'), findsOneWidget);
      expect(find.text('キャンセル'), findsOneWidget);
    });

    testWidgets('「ここに投稿」押下で onConfirm だけが呼ばれる', (tester) async {
      var confirmed = 0;
      var cancelled = 0;
      await tester.pumpWidget(
        _wrap(onConfirm: () => confirmed++, onCancel: () => cancelled++),
      );

      await tester.tap(find.text('ここに投稿'));
      await tester.pump();

      expect(confirmed, 1);
      expect(cancelled, 0);
    });

    testWidgets('「キャンセル」押下で onCancel だけが呼ばれる', (tester) async {
      var confirmed = 0;
      var cancelled = 0;
      await tester.pumpWidget(
        _wrap(onConfirm: () => confirmed++, onCancel: () => cancelled++),
      );

      await tester.tap(find.text('キャンセル'));
      await tester.pump();

      expect(confirmed, 0);
      expect(cancelled, 1);
    });
  });
}
