import 'dart:io';
import 'dart:typed_data';

import 'package:afterglow_app/data/services/image_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ImageService', () {
    late ImageService service;

    setUp(() {
      service = ImageService();
    });

    test('EXIF の GPS から東京駅の座標を読む', () async {
      final bytes = File(
        'test/fixtures/gps_tokyo_station.jpg',
      ).readAsBytesSync();
      final location = await service.extractGpsLocation(bytes);
      expect(location, isNotNull);
      expect(location!.latitude, closeTo(35.681167, 1e-4));
      expect(location.longitude, closeTo(139.767333, 1e-4));
    });

    test('GPS のない写真は null を返す', () async {
      final bytes = File('test/fixtures/no_gps.jpg').readAsBytesSync();
      expect(await service.extractGpsLocation(bytes), isNull);
    });

    test('壊れたバイト列でも例外を投げず null を返す', () async {
      expect(
        await service.extractGpsLocation(Uint8List.fromList([1, 2, 3])),
        isNull,
      );
    });

    test('許可拡張子（大文字含む）を受け入れる', () {
      expect(service.isAllowedExtension('photo.jpg'), isTrue);
      expect(service.isAllowedExtension('photo.jpeg'), isTrue);
      expect(service.isAllowedExtension('photo.PNG'), isTrue);
      expect(service.isAllowedExtension('photo.bmp'), isTrue);
      expect(service.isAllowedExtension('IMG_0001.HEIC'), isTrue);
    });

    test('非対応拡張子・拡張子なしを拒否する', () {
      expect(service.isAllowedExtension('photo.gif'), isFalse);
      expect(service.isAllowedExtension('video.mp4'), isFalse);
      expect(service.isAllowedExtension('document.pdf'), isFalse);
      expect(service.isAllowedExtension('noextension'), isFalse);
      expect(service.isAllowedExtension('trailingdot.'), isFalse);
    });

    test('サイズが上限内なら null を返す', () {
      final bytes = Uint8List(1024);
      expect(service.validateSizes([bytes, bytes]), isNull);
    });

    test('元画像は1枚30MBちょうどまで許容する', () {
      expect(ImageService.maxImageBytes, 30 * 1024 * 1024);
      final atLimit = Uint8List(ImageService.maxImageBytes);
      expect(service.validateSizes([atLimit]), isNull);
    });

    test('1枚が30MBを超えるとエラーを返す', () {
      final tooLarge = Uint8List(ImageService.maxImageBytes + 1);
      final error = service.validateSizes([tooLarge]);
      expect(error, isNotNull);
      expect(error, contains('30MB'));
    });

    test('圧縮後は10MB未満なら許容し、10MB以上なら拒否する', () {
      // storage.rules の `request.resource.size < 10 * 1024 * 1024` と揃える
      expect(ImageService.maxCompressedImageBytes, 10 * 1024 * 1024);
      expect(
        service.isCompressedSizeAllowed(
          Uint8List(ImageService.maxCompressedImageBytes - 1),
        ),
        isTrue,
      );
      expect(
        service.isCompressedSizeAllowed(
          Uint8List(ImageService.maxCompressedImageBytes),
        ),
        isFalse,
      );
    });

    test('合計が100MBを超えるとエラーを返す', () {
      // 各1枚上限内（25MB）の画像を5枚（合計125MB）で合計上限を超える
      final twentyFiveMb = Uint8List(25 * 1024 * 1024);
      final images = List<Uint8List>.filled(5, twentyFiveMb);
      final error = service.validateSizes(images);
      expect(error, isNotNull);
      expect(error, contains('100MB'));
    });
  });
}
