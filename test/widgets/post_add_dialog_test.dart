import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:afterglow_app/services/auth_service.dart';
import 'package:afterglow_app/services/contest_service.dart';
import 'package:afterglow_app/services/image_service.dart';
import 'package:afterglow_app/services/post_service.dart';
import 'package:afterglow_app/widgets/post_add_dialog.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:firebase_storage_mocks/firebase_storage_mocks.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';

/// `Dialog` の `insetPadding`（上下 24）と、ダイアログ内側の `Padding`（上 16 / 下 24）。
/// スクロール領域の高さはこの合計を差し引いた値になるはず。
const double _dialogInsetVertical = 24 * 2;
const double _contentPaddingVertical = 16 + 24;

/// 未初期化の Firebase に触れないよう、常にモックを注入したダイアログを組み立てる。
Widget _dialog({required double keyboardHeight, List<XFile>? initialImages}) {
  final firestore = FakeFirebaseFirestore();
  final postService = PostService(
    firestore: firestore,
    storage: MockFirebaseStorage(),
  );

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
            postService: postService,
            contestService: ContestService(
              firestore: firestore,
              postService: postService,
            ),
            authService: AuthService(
              auth: MockFirebaseAuth(),
              firestore: firestore,
            ),
            imageService: ImageService(),
            initialImages: initialImages,
          ),
        );
      },
    ),
  );
}

/// [color] 一色で塗った 4x4 の PNG を生成する。
/// 画像ごとに異なるバイト列を持たせ、並び替え後のプレビュー同期を検証する。
Future<Uint8List> _encodePng(Color color) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(const Rect.fromLTWH(0, 0, 4, 4), Paint()..color = color);
  final image = await recorder.endRecording().toImage(4, 4);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  return data!.buffer.asUint8List();
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

  testWidgets('キーボード表示時は画像プレビューが縮んで入力欄の余地を確保する', (tester) async {
    const keyboardHeight = 300.0;
    await pumpWithKeyboard(tester, keyboardHeight);

    // スクロール領域の高さ 312（700 - 300 - 48 - 40）から入力欄用の 280 を
    // 引くと最小高さ 96 を下回るため、プレビューは最小高さまで縮む。
    final previewRect = tester.getRect(find.byType(AspectRatio));
    expect(previewRect.height, closeTo(96.0, 1.0));
  });

  testWidgets('キーボード非表示時は画像プレビューが幅いっぱいの 4:3 のまま', (tester) async {
    await pumpWithKeyboard(tester, 0);

    // 幅 320（400 - insetPadding 48 - 内側 Padding 32）に対する 4:3 の高さ。
    // 高さに余裕があるためプレビューは縮まない。
    final previewRect = tester.getRect(find.byType(AspectRatio));
    expect(previewRect.width, closeTo(320.0, 5.0));
    expect(previewRect.height, closeTo(240.0, 5.0));
  });

  testWidgets('キーボード表示中に画面外の入力欄へフォーカスするとスクロールして表示される', (tester) async {
    const keyboardHeight = 300.0;
    await pumpWithKeyboard(tester, keyboardHeight);

    final tagField = find.widgetWithText(TextField, 'タグ（例: #夜景 #桜）');
    final scrollRect = tester.getRect(find.byType(SingleChildScrollView));

    // タグ入力欄はスクロール領域の外にあることを前提とする
    expect(tester.getRect(tagField).top, greaterThan(scrollRect.bottom));

    // タップの代わりにフォーカスだけ当てる（画面外でもフォーカスは可能）
    await tester.showKeyboard(tagField);
    await tester.pump();
    // フォーカス後のスクロール補正（350ms 待ち + 150ms アニメーション）
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    final tagRect = tester.getRect(tagField);
    expect(tagRect.top, greaterThanOrEqualTo(scrollRect.top - 1.0));
    expect(tagRect.bottom, lessThanOrEqualTo(scrollRect.bottom + 1.0));

    // ビューポート変化時の補正タイマーがテスト終了後に残らないよう解除する
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();
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

  group('画像の並び替え（Issue #40）', () {
    late XFile imageA;
    late XFile imageB;
    late XFile imageC;
    late Uint8List bytesA;
    late Uint8List bytesB;

    /// 3 枚の画像を選択済みの状態でダイアログを表示する。
    Future<void> pumpWithImages(WidgetTester tester) async {
      tester.view.physicalSize = screenSize;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      // PNG エンコードは実際のイベントループでしか完了しないため
      // フェイク非同期のテスト本体ではなく runAsync 内で行う。
      late Uint8List bytesC;
      await tester.runAsync(() async {
        bytesA = await _encodePng(const Color(0xFFFF0000));
        bytesB = await _encodePng(const Color(0xFF00FF00));
        bytesC = await _encodePng(const Color(0xFF0000FF));
      });
      imageA = XFile.fromData(bytesA, name: 'a.png');
      imageB = XFile.fromData(bytesB, name: 'b.png');
      imageC = XFile.fromData(bytesC, name: 'c.png');

      await tester.pumpWidget(
        _dialog(keyboardHeight: 0, initialImages: [imageA, imageB, imageC]),
      );
      await tester.pumpAndSettle();
    }

    /// サムネイル一覧内で [image] に対応するサムネイルを探す。
    Finder thumbnailOf(XFile image) => find.descendant(
      of: find.byType(ReorderableListView),
      matching: find.byKey(ObjectKey(image)),
    );

    testWidgets('画像が2枚以上のときサムネイル一覧が表示される', (tester) async {
      await pumpWithImages(tester);

      expect(find.byType(ReorderableListView), findsOneWidget);
      expect(thumbnailOf(imageA), findsOneWidget);
      expect(thumbnailOf(imageB), findsOneWidget);
      expect(thumbnailOf(imageC), findsOneWidget);
    });

    testWidgets('画像が1枚のときはサムネイル一覧を表示しない', (tester) async {
      tester.view.physicalSize = screenSize;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      late Uint8List bytes;
      await tester.runAsync(() async {
        bytes = await _encodePng(const Color(0xFFFF0000));
      });
      await tester.pumpWidget(
        _dialog(
          keyboardHeight: 0,
          initialImages: [XFile.fromData(bytes, name: 'a.png')],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ReorderableListView), findsNothing);
    });

    testWidgets('並び替えで選択画像とプレビューの順序が同期する', (tester) async {
      await pumpWithImages(tester);

      // 先頭（表示中）の画像を末尾へ移動する
      // （onReorder の移動先は「取り除く前」の位置なので末尾は 3）
      final list = tester.widget<ReorderableListView>(
        find.byType(ReorderableListView),
      );
      list.onReorder!(0, 3);
      await tester.pumpAndSettle();

      // サムネイルの並びが B, C, A になっていること
      final dxA = tester.getCenter(thumbnailOf(imageA)).dx;
      final dxB = tester.getCenter(thumbnailOf(imageB)).dx;
      final dxC = tester.getCenter(thumbnailOf(imageC)).dx;
      expect(dxB, lessThan(dxC));
      expect(dxC, lessThan(dxA));

      // 先頭サムネイルのバイト列も imageB のものに入れ替わっていること
      // （`_selectedImages` と `_previewImageBytes` の同期）
      final firstThumbnailImage = tester.widget<Image>(
        find.descendant(of: thumbnailOf(imageB), matching: find.byType(Image)),
      );
      expect((firstThumbnailImage.image as MemoryImage).bytes, same(bytesB));

      // 表示中だった画像（A）を追従してプレビューし続けること
      expect(find.text('3 / 3'), findsOneWidget);
    });

    testWidgets('長押しドラッグでサムネイルを並び替えられる', (tester) async {
      await pumpWithImages(tester);

      // タッチ端末（テスト既定は android）は長押しでドラッグを開始する
      final gesture = await tester.startGesture(
        tester.getCenter(thumbnailOf(imageA)),
      );
      await tester.pump(kLongPressTimeout + kPressTimeout);
      // 隣のサムネイル（幅 64 + 間隔 8）の位置まで動かして離す。
      // 1 回の大きな移動では挿入位置の再計算が追いつかないため、
      // 実際のドラッグと同じように少しずつ動かす。
      for (var i = 0; i < 4; i++) {
        await gesture.moveBy(const Offset(20, 0));
        await tester.pump();
      }
      await gesture.up();
      await tester.pumpAndSettle();

      // 並びが B, A, C になっていること
      final dxA = tester.getCenter(thumbnailOf(imageA)).dx;
      final dxB = tester.getCenter(thumbnailOf(imageB)).dx;
      final dxC = tester.getCenter(thumbnailOf(imageC)).dx;
      expect(dxB, lessThan(dxA));
      expect(dxA, lessThan(dxC));
    });

    testWidgets('並び替え後も画像の削除が正しく動作する', (tester) async {
      await pumpWithImages(tester);

      // 先頭の画像 A を末尾へ移動（A は表示中のまま）
      tester
          .widget<ReorderableListView>(find.byType(ReorderableListView))
          .onReorder!(0, 3);
      await tester.pumpAndSettle();

      // 表示中の画像（末尾の A）を削除する
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      expect(thumbnailOf(imageA), findsNothing);
      expect(thumbnailOf(imageB), findsOneWidget);
      expect(thumbnailOf(imageC), findsOneWidget);
      expect(find.text('2 / 2'), findsOneWidget);
    });
  });
}
