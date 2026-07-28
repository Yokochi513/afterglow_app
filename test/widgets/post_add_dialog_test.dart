import 'package:afterglow_app/services/auth_service.dart';
import 'package:afterglow_app/services/image_service.dart';
import 'package:afterglow_app/services/post_service.dart';
import 'package:afterglow_app/widgets/post_add_dialog.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:firebase_storage_mocks/firebase_storage_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

/// `Dialog` の `insetPadding`（上下 24）と、ダイアログ内側の `Padding`（上 16 / 下 24）。
/// スクロール領域の高さはこの合計を差し引いた値になるはず。
const double _dialogInsetVertical = 24 * 2;
const double _contentPaddingVertical = 16 + 24;

/// 未初期化の Firebase に触れないよう、常にモックを注入したダイアログを組み立てる。
Widget _dialog({required double keyboardHeight}) {
  final firestore = FakeFirebaseFirestore();

  return MaterialApp(
    home: Builder(
      builder: (context) {
        return MediaQuery(
          // キーボード表示を模擬する（viewInsets.bottom にキーボード高さが入る）
          data: MediaQuery.of(
            context,
          ).copyWith(viewInsets: EdgeInsets.only(bottom: keyboardHeight)),
          child: PostAddDialog(
            pos: const LatLng(35.0, 139.0),
            postService: PostService(
              firestore: firestore,
              storage: MockFirebaseStorage(),
            ),
            authService: AuthService(
              auth: MockFirebaseAuth(),
              firestore: firestore,
            ),
            imageService: ImageService(),
          ),
        );
      },
    ),
  );
}

void main() {
  // 画面が縦に狭い前提にして、キーボードの有無にかかわらず
  // ダイアログの中身がスクロール領域からあふれる状況を作る。
  const screenSize = Size(400, 700);

  Future<void> pumpWithKeyboard(
    WidgetTester tester,
    double keyboardHeight,
  ) async {
    tester.view.physicalSize = screenSize;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_dialog(keyboardHeight: keyboardHeight));
    await tester.pumpAndSettle();
  }

  testWidgets('キーボード表示時にキーボード分のパディングが二重に入らない', (tester) async {
    const keyboardHeight = 300.0;
    await pumpWithKeyboard(tester, keyboardHeight);

    final scrollRect = tester.getRect(find.byType(SingleChildScrollView));

    // Dialog がキーボード分を 1 回だけ差し引いた高さになっていること。
    // 二重にパディングされていると、この値からさらに keyboardHeight が引かれる。
    final expectedHeight =
        screenSize.height -
        keyboardHeight -
        _dialogInsetVertical -
        _contentPaddingVertical;

    expect(scrollRect.height, closeTo(expectedHeight, 1.0));
  });

  testWidgets('キーボード表示時にダイアログ下部へ空白領域が生じない', (tester) async {
    const keyboardHeight = 300.0;
    await pumpWithKeyboard(tester, keyboardHeight);

    final materialFinder = find
        .descendant(of: find.byType(Dialog), matching: find.byType(Material))
        .first;
    final materialRect = tester.getRect(materialFinder);
    final scrollRect = tester.getRect(find.byType(SingleChildScrollView));

    // ダイアログ本体はキーボードの上に収まること
    expect(
      materialRect.bottom,
      lessThanOrEqualTo(screenSize.height - keyboardHeight + 1.0),
    );

    // スクロール領域の下端とダイアログ下端の隙間は内側 Padding の 24 のみ。
    // 二重パディングのバグでは、ここに keyboardHeight 分の空白が生まれる。
    expect(materialRect.bottom - scrollRect.bottom, closeTo(24.0, 1.0));
  });

  testWidgets('キーボードを閉じるとレイアウトが元に戻る', (tester) async {
    await pumpWithKeyboard(tester, 0);

    final scrollRect = tester.getRect(find.byType(SingleChildScrollView));

    final expectedHeight =
        screenSize.height - _dialogInsetVertical - _contentPaddingVertical;

    expect(scrollRect.height, closeTo(expectedHeight, 1.0));
    expect(tester.takeException(), isNull);
  });

  testWidgets('キーボードインセットを処理する AnimatedPadding は Dialog の 1 つだけ', (
    tester,
  ) async {
    const keyboardHeight = 300.0;
    await pumpWithKeyboard(tester, keyboardHeight);

    // ダイアログ側で独自に AnimatedPadding を重ねると 2 つ以上になる（回帰検知）
    final animatedPaddings = find.descendant(
      of: find.byType(Dialog),
      matching: find.byType(AnimatedPadding),
    );
    expect(animatedPaddings, findsOneWidget);

    // 唯一の AnimatedPadding は Dialog 自身のもので、
    // 下パディングは insetPadding(24) + キーボード高さ の 1 回分だけであること。
    final padding = tester
        .widget<AnimatedPadding>(animatedPaddings)
        .padding
        .resolve(null);
    expect(padding.bottom, closeTo(24.0 + keyboardHeight, 0.1));
  });
}
