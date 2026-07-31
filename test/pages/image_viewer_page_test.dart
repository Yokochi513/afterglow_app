import 'package:afterglow_app/pages/image_viewer_page.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 全画面ビューア（Issue #45）のふるまい。
/// 画像はネットワークから読めないためプレースホルダーのままだが、
/// ページ送り・拡大の操作は確認できる。

const _urls = ['https://example.com/1.jpg', 'https://example.com/2.jpg'];

Widget _viewer({List<String> imageUrls = _urls, int initialIndex = 0}) {
  return MaterialApp(
    home: ImageViewerPage(imageUrls: imageUrls, initialIndex: initialIndex),
  );
}

/// PageView のスクロール可否（拡大中は止まる）。
ScrollPhysics? _pageViewPhysics(WidgetTester tester) {
  return tester
      .widget<PageView>(find.byKey(ImageViewerPage.pageViewKey))
      .physics;
}

Future<void> _doubleTapCenter(WidgetTester tester) async {
  final center = tester.getCenter(find.byType(InteractiveViewer).first);
  await tester.tapAt(center);
  await tester.pump(kDoubleTapMinTime);
  await tester.tapAt(center);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  testWidgets('複数枚のときは現在位置と枚数を表示する', (tester) async {
    await tester.pumpWidget(_viewer());

    expect(find.text('1 / 2'), findsOneWidget);
  });

  testWidgets('initialIndex で指定した写真から開く', (tester) async {
    await tester.pumpWidget(_viewer(initialIndex: 1));

    expect(find.text('2 / 2'), findsOneWidget);
  });

  testWidgets('範囲外の initialIndex は範囲内に丸める', (tester) async {
    await tester.pumpWidget(_viewer(initialIndex: 99));

    expect(find.text('2 / 2'), findsOneWidget);
  });

  testWidgets('矢印ボタンで次の写真へ送れる', (tester) async {
    await tester.pumpWidget(_viewer());

    await tester.tap(find.byIcon(Icons.chevron_right));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('2 / 2'), findsOneWidget);
  });

  testWidgets('1 枚のときは矢印を出さない', (tester) async {
    await tester.pumpWidget(
      _viewer(imageUrls: const ['https://example.com/1.jpg']),
    );

    expect(find.byIcon(Icons.chevron_left), findsNothing);
    expect(find.byIcon(Icons.chevron_right), findsNothing);
    expect(find.text('写真'), findsOneWidget);
  });

  testWidgets('写真はピンチ操作できる InteractiveViewer で表示する', (tester) async {
    await tester.pumpWidget(_viewer());

    expect(find.byType(InteractiveViewer), findsWidgets);
  });

  testWidgets('ダブルタップで拡大し、もう一度で元に戻る', (tester) async {
    await tester.pumpWidget(_viewer());

    expect(_pageViewPhysics(tester), isA<PageScrollPhysics>());

    // 拡大中はドラッグを写真の移動に使うため、ページ送りを止める
    await _doubleTapCenter(tester);
    expect(_pageViewPhysics(tester), isA<NeverScrollableScrollPhysics>());

    await _doubleTapCenter(tester);
    expect(_pageViewPhysics(tester), isA<PageScrollPhysics>());
  });

  testWidgets('画像が無くても落ちない', (tester) async {
    await tester.pumpWidget(_viewer(imageUrls: const []));

    expect(find.byIcon(Icons.image_not_supported), findsOneWidget);
  });
}
