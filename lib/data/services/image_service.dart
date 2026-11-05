import 'dart:typed_data';

import 'package:exif_reader/exif_reader.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
// XFile を明示的に参照するため image_picker を直接 import する
// （flutter_image_compress も再エクスポートするが、依存関係を明確にする）
// ignore: unnecessary_import
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';

/// 投稿画像の検証・圧縮を担うサービス（NFR_02 / §8.1）。
///
/// UI からは拡張子・サイズ検証に、`PostRepository` からはアップロード前の圧縮に
/// 利用する。DI 方針に従い、テストでは圧縮処理を差し替えられるよう
/// `compressImage` を override 可能にしている。
class ImageService {
  ImageService();

  /// 元画像の EXIF から撮影場所を読む。読めない場合は提案しない。
  Future<LatLng?> extractGpsLocation(Uint8List bytes) async {
    try {
      final data = await readExifFromBytes(bytes);
      double? coordinate(String name, String positive, String negative) {
        final values = data.tags['GPS GPS$name']?.values;
        final ref = data.tags['GPS GPS${name}Ref']?.printable;
        if (values is! IfdRatios ||
            values.ratios.length != 3 ||
            values.ratios.any((ratio) => ratio.denominator == 0) ||
            (ref != positive && ref != negative)) {
          return null;
        }
        final parts = values.ratios.map((ratio) => ratio.toDouble()).toList();
        if (parts.any((part) => !part.isFinite || part < 0) ||
            parts[1] >= 60 ||
            parts[2] >= 60) {
          return null;
        }
        final degrees = parts[0] + parts[1] / 60 + parts[2] / 3600;
        return ref == negative ? -degrees : degrees;
      }

      final latitude = coordinate('Latitude', 'N', 'S');
      final longitude = coordinate('Longitude', 'E', 'W');
      if (latitude == null ||
          longitude == null ||
          latitude.abs() > 90 ||
          longitude.abs() > 180 ||
          (latitude == 0 && longitude == 0)) {
        return null;
      }
      return LatLng(latitude, longitude);
    } catch (_) {
      return null;
    }
  }

  /// 許可する画像拡張子（NFR_02）。
  static const Set<String> allowedExtensions = {
    'jpg',
    'jpeg',
    'png',
    'bmp',
    'heic',
  };

  /// 圧縮前の元画像 1 枚あたりの最大バイト数（30MB, NFR_02 / Issue #99）。
  ///
  /// 実際にアップロードするのは圧縮後の画像なので、元画像は大きめに許容する。
  static const int maxImageBytes = 30 * 1024 * 1024;

  /// 圧縮前の元画像の合計の最大バイト数（100MB, NFR_02）。
  ///
  /// 元画像は投稿ダイアログがメモリに保持するため、合計は据え置く。
  static const int maxTotalBytes = 100 * 1024 * 1024;

  /// 圧縮後の画像 1 枚のバイト数の上限（この値未満のみ可, 10MB, Issue #99）。
  ///
  /// `storage.rules` の `request.resource.size < 10 * 1024 * 1024` と揃える。
  static const int maxCompressedImageBytes = 10 * 1024 * 1024;

  /// 圧縮後も上限以上となる画像があるときに表示するメッセージ。
  static const String compressedImageTooLargeMessage =
      '圧縮後も10MBを超える画像があるため投稿できません';

  /// 圧縮後の短辺目標（px, §8.1）。
  static const int maxShorterSidePixels = 2048;

  /// 圧縮品質（%, §8.1）。
  static const int compressQuality = 85;

  /// ファイル名の拡張子が許可対象かを判定する（NFR_02）。
  bool isAllowedExtension(String fileName) {
    final dotIndex = fileName.lastIndexOf('.');
    if (dotIndex < 0 || dotIndex == fileName.length - 1) {
      return false;
    }
    final extension = fileName.substring(dotIndex + 1).toLowerCase();
    return allowedExtensions.contains(extension);
  }

  /// 選択済み画像のバイト列を検証する（NFR_02）。
  ///
  /// 1枚でも30MBを超える、または合計が100MBを超える場合はエラーメッセージを
  /// 返す。問題がなければ null を返す。
  String? validateSizes(List<Uint8List> imageBytes) {
    var totalBytes = 0;
    for (final bytes in imageBytes) {
      if (bytes.length > maxImageBytes) {
        return '1枚あたり30MBを超える画像は投稿できません';
      }
      totalBytes += bytes.length;
    }
    if (totalBytes > maxTotalBytes) {
      return '画像の合計サイズが100MBを超えています';
    }
    return null;
  }

  /// 圧縮後のバイト列がアップロード可能な大きさ（10MB 未満）かを判定する。
  bool isCompressedSizeAllowed(Uint8List compressedBytes) =>
      compressedBytes.length < maxCompressedImageBytes;

  /// アップロード前に短辺2048px・品質85%の JPEG へ圧縮する（§8.1）。
  ///
  /// 短辺が2048px以下の画像は等倍のまま（`flutter_image_compress` は縮小のみ
  /// 行い拡大しない）。
  Future<Uint8List> compressImage(XFile image) async {
    final bytes = await image.readAsBytes();
    final compressed = await FlutterImageCompress.compressWithList(
      bytes,
      minWidth: maxShorterSidePixels,
      minHeight: maxShorterSidePixels,
      quality: compressQuality,
      format: CompressFormat.jpeg,
    );
    return compressed;
  }
}

/// 圧縮後も上限（[ImageService.maxCompressedImageBytes]）以上となる画像が
/// あるため、アップロードせずに投稿を中止したことを表す例外。
class CompressedImageTooLargeException implements Exception {
  const CompressedImageTooLargeException();

  /// 利用者に表示する理由。
  String get message => ImageService.compressedImageTooLargeMessage;

  @override
  String toString() => 'CompressedImageTooLargeException: $message';
}
