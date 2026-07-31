import 'dart:convert';

import 'package:afterglow_app/services/geocoding_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Nominatim 形式の検索結果 JSON（1 件分）。
Map<String, dynamic> _fakePlaceJson({
  String displayName = '岡山城, 丸の内, 岡山市, 岡山県, 日本',
  String lat = '34.665',
  String lon = '133.936',
}) {
  return {'display_name': displayName, 'lat': lat, 'lon': lon};
}

/// UTF-8 を明示した JSON レスポンス。`http.Response` は charset 指定がないと
/// latin1 でエンコードするため、日本語を含む本文はこれを使う。
http.Response _jsonResponse(String body, {int statusCode = 200}) {
  return http.Response(
    body,
    statusCode,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );
}

void main() {
  group('GeocodingService.search', () {
    test('検索結果をパースして候補リストを返す', () async {
      late Uri requestedUri;
      final client = MockClient((request) async {
        requestedUri = request.url;
        return _jsonResponse(jsonEncode([_fakePlaceJson()]));
      });
      final service = GeocodingService(client: client);

      final response = await service.search('岡山城');

      expect(response.isSuccess, isTrue);
      expect(response.places, hasLength(1));
      final place = response.places.first;
      expect(place.displayName, '岡山城, 丸の内, 岡山市, 岡山県, 日本');
      expect(place.latitude, 34.665);
      expect(place.longitude, 133.936);
      expect(requestedUri.host, 'nominatim.openstreetmap.org');
      expect(requestedUri.path, '/search');
      expect(requestedUri.queryParameters['q'], '岡山城');
      expect(requestedUri.queryParameters['format'], 'jsonv2');
    });

    test('該当なし（空配列）は成功かつ 0 件を返す', () async {
      final client = MockClient((request) async => http.Response('[]', 200));
      final service = GeocodingService(client: client);

      final response = await service.search('存在しない場所名xyz');

      expect(response.isSuccess, isTrue);
      expect(response.places, isEmpty);
    });

    test('空クエリは API を呼ばず成功 0 件を返す', () async {
      var called = false;
      final client = MockClient((request) async {
        called = true;
        return http.Response('[]', 200);
      });
      final service = GeocodingService(client: client);

      final response = await service.search('   ');

      expect(called, isFalse, reason: '空クエリで無駄なリクエストを送らない');
      expect(response.isSuccess, isTrue);
      expect(response.places, isEmpty);
    });

    test('HTTP エラー（非 200）は失敗を返す', () async {
      final client = MockClient(
        (request) async => http.Response('Too Many Requests', 429),
      );
      final service = GeocodingService(client: client);

      final response = await service.search('岡山城');

      expect(response.isSuccess, isFalse);
      expect(response.places, isEmpty);
    });

    test('レスポンスが JSON 配列でなければ失敗を返す', () async {
      final client = MockClient(
        (request) async => http.Response('{"error": "bad"}', 200),
      );
      final service = GeocodingService(client: client);

      final response = await service.search('岡山城');

      expect(response.isSuccess, isFalse);
    });

    test('通信例外が起きても例外を投げず失敗を返す', () async {
      final client = MockClient(
        (request) async => throw http.ClientException('network down'),
      );
      final service = GeocodingService(client: client);

      final response = await service.search('岡山城');

      expect(response.isSuccess, isFalse);
    });

    test('lat/lon が不正な文字列でも 0 にフォールバックする', () async {
      final client = MockClient(
        (request) async =>
            _jsonResponse(jsonEncode([_fakePlaceJson(lat: 'abc', lon: '')])),
      );
      final service = GeocodingService(client: client);

      final response = await service.search('岡山城');

      expect(response.isSuccess, isTrue);
      expect(response.places.first.latitude, 0);
      expect(response.places.first.longitude, 0);
    });
  });
}
