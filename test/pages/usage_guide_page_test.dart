import 'package:afterglow_app/pages/usage_guide_page.dart';
import 'package:afterglow_app/widgets/usage_guide_dialog.dart';
import 'package:afterglow_app/widgets/usage_guide_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 使い方ガイド（Issue #47）の表示。ページ・ダイアログのどちらからでも
/// 同じ内容が読め、Issue の主目的である「自分の投稿の探し方」が載っている。

void main() {
  testWidgets('ページにすべての項目を表示する', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: UsageGuidePage()));

    expect(find.text('使い方ガイド'), findsOneWidget);
    for (final section in UsageGuideView.sections) {
      expect(find.text(section.title), findsOneWidget);
    }
  });

  testWidgets('自分の投稿の探し方を案内する', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: UsageGuidePage()));

    expect(find.text('自分の投稿を見る・編集する'), findsOneWidget);
    expect(
      find.textContaining('プロフィールボタン', findRichText: true),
      findsOneWidget,
    );
  });

  testWidgets('ダイアログでも同じ内容を表示し、閉じられる', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => UsageGuideDialog.show(context),
              child: const Text('開く'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('開く'));
    await tester.pumpAndSettle();

    expect(find.byType(UsageGuideView), findsOneWidget);
    expect(find.text('Afterglow の使い方'), findsOneWidget);

    await tester.tap(find.text('はじめる'));
    await tester.pumpAndSettle();

    expect(find.byType(UsageGuideView), findsNothing);
  });
}
