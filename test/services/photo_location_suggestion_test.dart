import 'package:afterglow_app/services/photo_location_suggestion.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

void main() {
  const tapped = LatLng(35, 139);
  const adopted = LatLng(36, 140);
  const other = LatLng(37, 141);
  const distance = Distance(roundResult: false);

  PhotoLocationResult evaluate(
    List<LatLng?> photos, {
    LatLng? current,
    LatLng? ignored,
  }) => PhotoLocationSuggestions.evaluate(
    photoLocations: photos,
    tappedLocation: tapped,
    adoptedLocation: current,
    ignoredLocation: ignored,
  );

  test('GPS がなければ提案しない', () {
    expect(evaluate([]), isA<NoPhotoLocationSuggestion>());
    expect(evaluate([null, null]), isA<NoPhotoLocationSuggestion>());
  });

  test('タップ地点から 50m 以内は提案せず、超えたら提案する', () {
    expect(
      evaluate([distance.offset(tapped, 49.9, 0)]),
      isA<NoPhotoLocationSuggestion>(),
    );
    expect(
      evaluate([distance.offset(tapped, 50.1, 0)]),
      isA<PhotoLocationSuggestion>(),
    );
  });

  test('null を飛ばして先頭の GPS 付き写真を番号付きで提案する', () {
    final result = evaluate([null, adopted, other]) as PhotoLocationSuggestion;
    expect(result.location, adopted);
    expect(result.photoNumber, 2);
    expect(result.distanceMeters, closeTo(distance(tapped, adopted), 0.01));
    expect(result.isReproposal, isFalse);
    expect(evaluate([tapped, other]), isA<NoPhotoLocationSuggestion>());
  });

  test('採用位置に該当する写真が全て消えたらタップ地点へ戻す', () {
    expect(evaluate([], current: adopted), isA<RestoreTappedLocation>());
    expect(evaluate([null], current: adopted), isA<RestoreTappedLocation>());
    expect(evaluate([other], current: adopted), isA<RestoreTappedLocation>());
  });

  test('採用位置に該当する写真が残っていれば位置を維持する', () {
    final result =
        evaluate([distance.offset(adopted, 49.9, 0), other], current: adopted)
            as PhotoLocationAdopted;
    expect(result.location, adopted);
    expect(
      evaluate([distance.offset(adopted, 50.1, 0)], current: adopted),
      isA<RestoreTappedLocation>(),
    );
  });

  test('先頭候補が変わっても採用写真が残っていれば再提案するだけ', () {
    final result =
        evaluate([null, other, adopted], current: adopted)
            as PhotoLocationSuggestion;
    expect(result.location, other);
    expect(result.photoNumber, 2);
    expect(result.isReproposal, isTrue);
  });

  test('無視した座標から 50m 以内は抑制し、超えたら再提案する', () {
    expect(
      evaluate([distance.offset(adopted, 49.9, 0)], ignored: adopted),
      isA<NoPhotoLocationSuggestion>(),
    );
    expect(
      evaluate([distance.offset(adopted, 50.1, 0)], ignored: adopted),
      isA<PhotoLocationSuggestion>(),
    );
    final result =
        evaluate([other, adopted], current: adopted, ignored: other)
            as PhotoLocationAdopted;
    expect(result.location, adopted);
  });

  test('距離は 1km 未満なら m、それ以上なら小数 1 桁の km', () {
    expect(PhotoLocationSuggestions.formatDistance(350), '約 350m');
    expect(PhotoLocationSuggestions.formatDistance(999), '約 999m');
    expect(PhotoLocationSuggestions.formatDistance(1000), '約 1.0km');
    expect(PhotoLocationSuggestions.formatDistance(1234), '約 1.2km');
  });
}
