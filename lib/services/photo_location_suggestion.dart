import 'package:latlong2/latlong.dart';

/// 写真の撮影場所（EXIF の GPS）に関する判定結果（Issue #46）。
sealed class PhotoLocationResult {
  const PhotoLocationResult();
}

/// 提案も採用もしていない状態。GPS 付き写真がない場合もこれになる。
final class NoPhotoLocationSuggestion extends PhotoLocationResult {
  const NoPhotoLocationSuggestion();
}

/// 撮影場所への差し替えを提案する状態。
final class PhotoLocationSuggestion extends PhotoLocationResult {
  const PhotoLocationSuggestion({
    required this.location,
    required this.photoNumber,
    required this.distanceMeters,
    required this.isReproposal,
  });

  /// 提案する撮影場所。
  final LatLng location;

  /// 何枚目の写真の撮影場所か（1 始まり）。
  final int photoNumber;

  /// タップ地点からの距離（m）。
  final double distanceMeters;

  /// 採用中に別の撮影場所へ変わったことによる再提案か。
  final bool isReproposal;
}

/// 撮影場所を採用して投稿位置にしている状態。
final class PhotoLocationAdopted extends PhotoLocationResult {
  const PhotoLocationAdopted(this.location);

  final LatLng location;
}

/// 採用した撮影場所の写真がなくなり、タップ地点へ戻すべき状態。
final class RestoreTappedLocation extends PhotoLocationResult {
  const RestoreTappedLocation();
}

/// 写真の並び順と確認済みの位置から、次に表示する状態を決める。
class PhotoLocationSuggestions {
  /// この距離以内なら同じ場所とみなし、提案しない（m）。
  static const double thresholdMeters = 50;
  static const Distance _distance = Distance(roundResult: false);

  static PhotoLocationResult evaluate({
    required List<LatLng?> photoLocations,
    required LatLng tappedLocation,
    LatLng? adoptedLocation,
    LatLng? ignoredLocation,
  }) {
    if (adoptedLocation != null &&
        !photoLocations.any(
          (location) =>
              location != null &&
              _distance(adoptedLocation, location) <= thresholdMeters,
        )) {
      return const RestoreTappedLocation();
    }

    final index = photoLocations.indexWhere((location) => location != null);
    if (index < 0) {
      return const NoPhotoLocationSuggestion();
    }
    final candidate = photoLocations[index]!;
    final distance = _distance(tappedLocation, candidate);
    if (distance <= thresholdMeters ||
        (ignoredLocation != null &&
            _distance(ignoredLocation, candidate) <= thresholdMeters) ||
        (adoptedLocation != null &&
            _distance(adoptedLocation, candidate) <= thresholdMeters)) {
      return adoptedLocation == null
          ? const NoPhotoLocationSuggestion()
          : PhotoLocationAdopted(adoptedLocation);
    }
    return PhotoLocationSuggestion(
      location: candidate,
      photoNumber: index + 1,
      distanceMeters: distance,
      isReproposal: adoptedLocation != null,
    );
  }

  /// 距離を「約 350m」「約 1.2km」の形式にする。
  static String formatDistance(double meters) => meters < 1000
      ? '約 ${meters.round()}m'
      : '約 ${(meters / 1000).toStringAsFixed(1)}km';
}
