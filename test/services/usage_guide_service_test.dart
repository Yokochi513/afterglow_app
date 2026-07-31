import 'package:afterglow_app/services/usage_guide_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

UsageGuideService _service() {
  return UsageGuideService(preferencesProvider: SharedPreferences.getInstance);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('初回起動（未記録）ならガイドを表示する', () async {
    expect(await _service().shouldShowGuide(), isTrue);
  });

  test('表示済みを記録すると次回は表示しない', () async {
    final service = _service();

    await service.markGuideShown();

    expect(await service.shouldShowGuide(), isFalse);
  });

  test('記録済みの値を読み込んだ状態でも表示しない', () async {
    SharedPreferences.setMockInitialValues({
      UsageGuideService.guideShownKey: true,
    });

    expect(await _service().shouldShowGuide(), isFalse);
  });
}
