import 'dart:typed_data';

import 'package:afterglow_app/services/image_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ImageService', () {
    late ImageService service;

    setUp(() {
      service = ImageService();
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

    test('1枚が10MBを超えるとエラーを返す', () {
      final tooLarge = Uint8List(ImageService.maxImageBytes + 1);
      final error = service.validateSizes([tooLarge]);
      expect(error, isNotNull);
      expect(error, contains('10MB'));
    });

    test('合計が100MBを超えるとエラーを返す', () {
      // 各9MBの画像を12枚（合計108MB）で合計上限を超える
      final nineMb = Uint8List(9 * 1024 * 1024);
      final images = List<Uint8List>.filled(12, nineMb);
      final error = service.validateSizes(images);
      expect(error, isNotNull);
      expect(error, contains('100MB'));
    });
  });
}
