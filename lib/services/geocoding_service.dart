import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

/// 場所検索（ジオコーディング）の 1 件分の結果。
class PlaceSearchResult {
  const PlaceSearchResult({
    required this.displayName,
    required this.latitude,
    required this.longitude,
  });

  /// Nominatim のレスポンス 1 件分（JSON マップ）から生成する。
  /// lat / lon は文字列で返るため数値へ変換し、欠損・不正値は 0 に落とす。
  factory PlaceSearchResult.fromJson(Map<String, dynamic> json) {
    return PlaceSearchResult(
      displayName: json['display_name'] as String? ?? '',
      latitude: double.tryParse(json['lat'] as String? ?? '') ?? 0,
      longitude: double.tryParse(json['lon'] as String? ?? '') ?? 0,
    );
  }

  /// 住所を含む表示名（例: 「岡山城, 丸の内, 岡山市, 岡山県, 日本」）。
  final String displayName;
  final double latitude;
  final double longitude;
}

/// 場所検索の結果。成功時は [places]（0 件 = 該当なし）、失敗時は
/// [isSuccess] が false になる。ネットワーク断や API エラーでも例外を
/// 投げず、この型で理由を UI 側へ返す（[LocationResult] と同じ流儀）。
class PlaceSearchResponse {
  const PlaceSearchResponse.success(this.places) : isSuccess = true;

  const PlaceSearchResponse.failure() : places = const [], isSuccess = false;

  final List<PlaceSearchResult> places;
  final bool isSuccess;
}

/// 地名・施設名から座標を検索するジオコーディングのサービス層。
///
/// OSM Nominatim の検索 API を利用する（タイルと同じ OSM 系で親和性が高い）。
/// 利用ポリシー上、リクエストは 1 秒 1 回まで・アプリを特定できる
/// User-Agent が必要（Web では ブラウザが UA を付与するため設定不可）。
/// 呼び出し側は入力確定時のみ検索する（逐次のオートコンプリートはしない）。
class GeocodingService {
  GeocodingService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const String _host = 'nominatim.openstreetmap.org';

  /// 一度に取得する最大候補数。
  static const int _limit = 5;

  /// 検索リクエストの最大待機時間。
  static const Duration _timeLimit = Duration(seconds: 10);

  /// [query]（地名・施設名）を検索し、候補を返す。
  ///
  /// 空クエリは検索せず成功（0 件）を返す。HTTP エラー・タイムアウト・
  /// パース失敗はすべて [PlaceSearchResponse.failure] に丸める。
  Future<PlaceSearchResponse> search(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      return const PlaceSearchResponse.success([]);
    }

    final uri = Uri.https(_host, '/search', {
      'q': trimmed,
      'format': 'jsonv2',
      'limit': '$_limit',
      'accept-language': 'ja',
    });

    try {
      final response = await _client
          .get(uri, headers: const {'User-Agent': 'afterglow_app'})
          .timeout(_timeLimit);
      if (response.statusCode != 200) {
        return const PlaceSearchResponse.failure();
      }

      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! List) {
        return const PlaceSearchResponse.failure();
      }

      final places = decoded
          .whereType<Map<String, dynamic>>()
          .map(PlaceSearchResult.fromJson)
          .toList();
      return PlaceSearchResponse.success(places);
    } catch (_) {
      return const PlaceSearchResponse.failure();
    }
  }
}
