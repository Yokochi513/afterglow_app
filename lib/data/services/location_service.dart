import 'dart:async';

import 'package:geolocator/geolocator.dart';

/// 現在地取得に失敗した理由の種別。UI 側はこれを見て案内メッセージを出し分ける。
enum LocationErrorType {
  /// 端末の位置情報サービス（GPS）が無効になっている。
  serviceDisabled,

  /// 位置情報の利用が拒否された（再度要求すれば許可され得る）。
  permissionDenied,

  /// 位置情報の利用が永久的に拒否されている（端末設定からの許可が必要）。
  permissionDeniedForever,

  /// 取得がタイムアウトした。
  timeout,

  /// その他の予期しない失敗。
  unknown,
}

/// 現在地取得の結果。成功時は [position]、失敗時は [errorType] のいずれかを持つ。
class LocationResult {
  const LocationResult.success(Position this.position) : errorType = null;

  const LocationResult.failure(LocationErrorType this.errorType)
    : position = null;

  final Position? position;
  final LocationErrorType? errorType;

  bool get isSuccess => position != null;
}

/// 位置情報（GPS）へのアクセスを担うサービス層。
///
/// `geolocator` の静的 API を関数として注入できる形にし、テストからモックを
/// 差し込めるようにしている（既定値は実際の [Geolocator] を呼ぶ）。
class LocationService {
  LocationService({
    Future<bool> Function()? isLocationServiceEnabled,
    Future<LocationPermission> Function()? checkPermission,
    Future<LocationPermission> Function()? requestPermission,
    Future<Position> Function({LocationSettings? locationSettings})?
    getCurrentPosition,
    Future<bool> Function()? openAppSettings,
  }) : _isLocationServiceEnabled =
           isLocationServiceEnabled ?? Geolocator.isLocationServiceEnabled,
       _checkPermission = checkPermission ?? Geolocator.checkPermission,
       _requestPermission = requestPermission ?? Geolocator.requestPermission,
       _getCurrentPosition =
           getCurrentPosition ?? Geolocator.getCurrentPosition,
       _openAppSettings = openAppSettings ?? Geolocator.openAppSettings;

  final Future<bool> Function() _isLocationServiceEnabled;
  final Future<LocationPermission> Function() _checkPermission;
  final Future<LocationPermission> Function() _requestPermission;
  final Future<Position> Function({LocationSettings? locationSettings})
  _getCurrentPosition;
  final Future<bool> Function() _openAppSettings;

  /// 現在地の取得までに許容する最大待機時間。
  static const Duration _timeLimit = Duration(seconds: 15);

  /// 現在地を取得する。
  ///
  /// 位置情報サービスの有効性・パーミッションを順に確認し、未許可なら要求する。
  /// いずれの失敗ケースでも例外を投げず、[LocationResult] で理由を返す。
  Future<LocationResult> getCurrentLocation() async {
    try {
      if (!await _isLocationServiceEnabled()) {
        return const LocationResult.failure(LocationErrorType.serviceDisabled);
      }

      var permission = await _checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await _requestPermission();
      }

      if (permission == LocationPermission.deniedForever) {
        return const LocationResult.failure(
          LocationErrorType.permissionDeniedForever,
        );
      }
      if (permission == LocationPermission.denied) {
        return const LocationResult.failure(LocationErrorType.permissionDenied);
      }

      final position = await _getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: _timeLimit,
        ),
      );
      return LocationResult.success(position);
    } on TimeoutException {
      return const LocationResult.failure(LocationErrorType.timeout);
    } on LocationServiceDisabledException {
      return const LocationResult.failure(LocationErrorType.serviceDisabled);
    } catch (_) {
      return const LocationResult.failure(LocationErrorType.unknown);
    }
  }

  /// 端末のアプリ設定画面を開く（永久拒否からの復帰導線）。
  Future<bool> openAppSettings() => _openAppSettings();

  /// 失敗理由に対応するユーザー向けメッセージ（日本語）を返す。
  static String messageFor(LocationErrorType type) {
    switch (type) {
      case LocationErrorType.serviceDisabled:
        return '位置情報サービスが無効です。端末の設定でオンにしてください。';
      case LocationErrorType.permissionDenied:
        return '位置情報の利用が許可されませんでした。';
      case LocationErrorType.permissionDeniedForever:
        return '位置情報の利用が拒否されています。設定から許可してください。';
      case LocationErrorType.timeout:
        return '現在地の取得がタイムアウトしました。時間をおいて再度お試しください。';
      case LocationErrorType.unknown:
        return '現在地を取得できませんでした。';
    }
  }
}
