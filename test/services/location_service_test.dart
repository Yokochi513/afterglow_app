import 'dart:async';

import 'package:afterglow_app/services/location_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';

/// テスト用のダミー現在地。
Position _fakePosition({double lat = 35.0, double lng = 139.0}) {
  return Position(
    latitude: lat,
    longitude: lng,
    timestamp: DateTime.fromMillisecondsSinceEpoch(0),
    accuracy: 1,
    altitude: 0,
    altitudeAccuracy: 0,
    heading: 0,
    headingAccuracy: 0,
    speed: 0,
    speedAccuracy: 0,
  );
}

void main() {
  group('LocationService.getCurrentLocation', () {
    test('位置情報サービスが無効なら serviceDisabled を返す', () async {
      final service = LocationService(
        isLocationServiceEnabled: () async => false,
        checkPermission: () async => LocationPermission.always,
        requestPermission: () async => LocationPermission.always,
        getCurrentPosition: ({LocationSettings? locationSettings}) async =>
            _fakePosition(),
      );

      final result = await service.getCurrentLocation();

      expect(result.isSuccess, isFalse);
      expect(result.errorType, LocationErrorType.serviceDisabled);
    });

    test('拒否のまま再要求も拒否なら permissionDenied を返す', () async {
      var requested = false;
      final service = LocationService(
        isLocationServiceEnabled: () async => true,
        checkPermission: () async => LocationPermission.denied,
        requestPermission: () async {
          requested = true;
          return LocationPermission.denied;
        },
        getCurrentPosition: ({LocationSettings? locationSettings}) async =>
            _fakePosition(),
      );

      final result = await service.getCurrentLocation();

      expect(requested, isTrue, reason: '未許可時は要求ダイアログを出す');
      expect(result.errorType, LocationErrorType.permissionDenied);
    });

    test('永久拒否なら permissionDeniedForever を返す', () async {
      final service = LocationService(
        isLocationServiceEnabled: () async => true,
        checkPermission: () async => LocationPermission.deniedForever,
        requestPermission: () async => LocationPermission.deniedForever,
        getCurrentPosition: ({LocationSettings? locationSettings}) async =>
            _fakePosition(),
      );

      final result = await service.getCurrentLocation();

      expect(result.errorType, LocationErrorType.permissionDeniedForever);
    });

    test('要求で許可されれば現在地を返す', () async {
      final service = LocationService(
        isLocationServiceEnabled: () async => true,
        checkPermission: () async => LocationPermission.denied,
        requestPermission: () async => LocationPermission.whileInUse,
        getCurrentPosition: ({LocationSettings? locationSettings}) async =>
            _fakePosition(lat: 34.5, lng: 133.9),
      );

      final result = await service.getCurrentLocation();

      expect(result.isSuccess, isTrue);
      expect(result.position?.latitude, 34.5);
      expect(result.position?.longitude, 133.9);
    });

    test('取得がタイムアウトすれば timeout を返す', () async {
      final service = LocationService(
        isLocationServiceEnabled: () async => true,
        checkPermission: () async => LocationPermission.always,
        requestPermission: () async => LocationPermission.always,
        getCurrentPosition: ({LocationSettings? locationSettings}) async =>
            throw TimeoutException('timeout'),
      );

      final result = await service.getCurrentLocation();

      expect(result.errorType, LocationErrorType.timeout);
    });

    test('取得中の位置サービス無効例外は serviceDisabled を返す', () async {
      final service = LocationService(
        isLocationServiceEnabled: () async => true,
        checkPermission: () async => LocationPermission.always,
        requestPermission: () async => LocationPermission.always,
        getCurrentPosition: ({LocationSettings? locationSettings}) async =>
            throw const LocationServiceDisabledException(),
      );

      final result = await service.getCurrentLocation();

      expect(result.errorType, LocationErrorType.serviceDisabled);
    });

    test('予期しない例外は unknown を返す', () async {
      final service = LocationService(
        isLocationServiceEnabled: () async => true,
        checkPermission: () async => LocationPermission.always,
        requestPermission: () async => LocationPermission.always,
        getCurrentPosition: ({LocationSettings? locationSettings}) async =>
            throw Exception('boom'),
      );

      final result = await service.getCurrentLocation();

      expect(result.errorType, LocationErrorType.unknown);
    });
  });

  group('LocationService.messageFor', () {
    test('全ての失敗種別で非空メッセージを返す', () {
      for (final type in LocationErrorType.values) {
        expect(LocationService.messageFor(type), isNotEmpty);
      }
    });
  });
}
