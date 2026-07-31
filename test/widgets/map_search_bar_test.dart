import 'dart:convert';

import 'package:afterglow_app/services/geocoding_service.dart';
import 'package:afterglow_app/widgets/map_search_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// 固定レスポンスを返す [GeocodingService] を組み立てる。
GeocodingService _serviceWith(http.Response response) {
  return GeocodingService(client: MockClient((request) async => response));
}

/// UTF-8 を明示した JSON レスポンス。`http.Response` は charset 指定がないと
/// latin1 でエンコードするため、日本語を含む本文はこれを使う。
http.Response _jsonResponse(String body) {
  return http.Response(
    body,
    200,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );
}

Widget _wrap(Widget child) {
  return MaterialApp(home: Scaffold(body: child));
}

void main() {
  final okayamaCastle = jsonEncode([
    {
      'display_name': '岡山城, 丸の内, 岡山市, 岡山県, 日本',
      'lat': '34.665',
      'lon': '133.936',
    },
  ]);

  testWidgets('検索を確定すると候補が表示され、選択でコールバックが呼ばれる', (tester) async {
    PlaceSearchResult? selected;
    await tester.pumpWidget(
      _wrap(
        MapSearchBar(
          geocodingService: _serviceWith(_jsonResponse(okayamaCastle)),
          onPlaceSelected: (place) => selected = place,
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), '岡山城');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    expect(find.text('岡山城, 丸の内, 岡山市, 岡山県, 日本'), findsOneWidget);

    await tester.tap(find.text('岡山城, 丸の内, 岡山市, 岡山県, 日本'));
    await tester.pumpAndSettle();

    expect(selected, isNotNull);
    expect(selected!.latitude, 34.665);
    expect(selected!.longitude, 133.936);
    // 選択後は候補一覧が閉じる
    expect(find.text('岡山城, 丸の内, 岡山市, 岡山県, 日本'), findsNothing);
  });

  testWidgets('該当なしのときはメッセージを表示する', (tester) async {
    await tester.pumpWidget(
      _wrap(
        MapSearchBar(
          geocodingService: _serviceWith(http.Response('[]', 200)),
          onPlaceSelected: (_) {},
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), '存在しない場所名xyz');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    expect(find.text('該当する場所が見つかりませんでした。'), findsOneWidget);
  });

  testWidgets('検索失敗時はエラーメッセージを表示する', (tester) async {
    await tester.pumpWidget(
      _wrap(
        MapSearchBar(
          geocodingService: _serviceWith(http.Response('error', 500)),
          onPlaceSelected: (_) {},
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), '岡山城');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    expect(find.text('検索に失敗しました。時間をおいて再度お試しください。'), findsOneWidget);
  });

  testWidgets('クリアボタンで入力と候補が消える', (tester) async {
    await tester.pumpWidget(
      _wrap(
        MapSearchBar(
          geocodingService: _serviceWith(_jsonResponse(okayamaCastle)),
          onPlaceSelected: (_) {},
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), '岡山城');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(find.text('岡山城, 丸の内, 岡山市, 岡山県, 日本'), findsOneWidget);

    await tester.tap(find.byTooltip('クリア'));
    await tester.pumpAndSettle();

    expect(find.text('岡山城, 丸の内, 岡山市, 岡山県, 日本'), findsNothing);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      isEmpty,
    );
  });

  testWidgets('空の入力では検索されず候補パネルも出ない', (tester) async {
    var called = false;
    final service = GeocodingService(
      client: MockClient((request) async {
        called = true;
        return http.Response('[]', 200);
      }),
    );
    await tester.pumpWidget(
      _wrap(MapSearchBar(geocodingService: service, onPlaceSelected: (_) {})),
    );

    await tester.tap(find.byTooltip('検索'));
    await tester.pumpAndSettle();

    expect(called, isFalse);
    expect(find.byType(ListTile), findsNothing);
  });
}
