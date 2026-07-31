import 'package:afterglow_app/pages/location_picker_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

const LatLng _initialPosition = LatLng(35.0, 139.0);

Widget _wrap() => const MaterialApp(
  home: LocationPickerPage(initialPosition: _initialPosition),
);

void main() {
  group('LocationPickerPage', () {
    testWidgets('初期状態では現在位置のピンだけを表示し、確認バーは出さない', (tester) async {
      await tester.pumpWidget(_wrap());

      expect(find.text('位置を選び直す'), findsOneWidget);
      expect(find.byIcon(Icons.location_on), findsOneWidget);
      expect(find.byIcon(Icons.add_location_alt), findsNothing);
      expect(find.text('この場所に変更しますか？'), findsNothing);
    });

    testWidgets('地図タップで選択マーカーと確認バーが表示される', (tester) async {
      await tester.pumpWidget(_wrap());

      await tester.tap(find.byType(FlutterMap));
      // flutter_map はダブルタップと区別するためシングルタップを遅延処理する
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byIcon(Icons.add_location_alt), findsOneWidget);
      expect(find.text('この場所に変更しますか？'), findsOneWidget);
      expect(find.text('この場所にする'), findsOneWidget);
    });

    testWidgets('「キャンセル」で選択マーカーと確認バーが消える', (tester) async {
      await tester.pumpWidget(_wrap());

      await tester.tap(find.byType(FlutterMap));
      // flutter_map はダブルタップと区別するためシングルタップを遅延処理する
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('キャンセル'));
      // 確認バー（bottomSheet）の退場アニメーションを進める
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byIcon(Icons.add_location_alt), findsNothing);
      expect(find.text('この場所に変更しますか？'), findsNothing);
    });

    testWidgets('確定でタップした位置の LatLng を返す', (tester) async {
      LatLng? result;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () async {
                    result = await Navigator.of(context).push<LatLng>(
                      MaterialPageRoute<LatLng>(
                        builder: (_) => const LocationPickerPage(
                          initialPosition: _initialPosition,
                        ),
                      ),
                    );
                  },
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // 地図の中心（＝初期位置付近）をタップして確定する
      await tester.tap(find.byType(FlutterMap));
      // flutter_map はダブルタップと区別するためシングルタップを遅延処理する
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('この場所にする'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(result, isNotNull);
      expect(result!.latitude, closeTo(_initialPosition.latitude, 0.01));
      expect(result!.longitude, closeTo(_initialPosition.longitude, 0.01));
    });
  });
}
