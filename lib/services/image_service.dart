import 'dart:typed_data';

import 'package:flutter_image_compress/flutter_image_compress.dart';
// XFile を明示的に参照するため image_picker を直接 import する
// （flutter_image_compress も再エクスポートするが、依存関係を明確にする）
// ignore: unnecessary_import
import 'package:image_picker/image_picker.dart';

/// 投稿画像の検証・圧縮を担うサービス（NFR_02 / §8.1）。
///
/// UI からは拡張子・サイズ検証に、`PostService` からはアップロード前の圧縮に
/// 利用する。DI 方針に従い、テストでは圧縮処理を差し替えられるよう
/// `compressImage` を override 可能にしている。
class ImageService {
  ImageService();

  /// 許可する画像拡張子（NFR_02）。
  static const Set<String> allowedExtensions = {
    'jpg',
    'jpeg',
    'png',
    'bmp',
    'heic',
  };

  /// 1枚あたりの最大バイト数（10MB, NFR_02）。
  static const int maxImageBytes = 10 * 1024 * 1024;

  /// 画像全体の最大バイト数（100MB, NFR_02）。
  static const int maxTotalBytes = 100 * 1024 * 1024;

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
  /// 1枚でも10MBを超える、または合計が100MBを超える場合はエラーメッセージを
  /// 返す。問題がなければ null を返す。
  String? validateSizes(List<Uint8List> imageBytes) {
    var totalBytes = 0;
    for (final bytes in imageBytes) {
      if (bytes.length > maxImageBytes) {
        return '1枚あたり10MBを超える画像は投稿できません';
      }
      totalBytes += bytes.length;
    }
    if (totalBytes > maxTotalBytes) {
      return '画像の合計サイズが100MBを超えています';
    }
    return null;
  }

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
