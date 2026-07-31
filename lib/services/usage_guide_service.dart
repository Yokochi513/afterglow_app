import 'package:shared_preferences/shared_preferences.dart';

/// 使い方ガイド（Issue #47）の表示状態を保持するデータ層。
///
/// 初回起動でガイドを自動表示したかどうかを `shared_preferences` に記録する。
/// テストからモックを注入できるよう、設定ストレージはコンストラクタで
/// 差し替え可能にしている。
class UsageGuideService {
  UsageGuideService({Future<SharedPreferences> Function()? preferencesProvider})
    : _preferencesProvider =
          preferencesProvider ?? SharedPreferences.getInstance;

  final Future<SharedPreferences> Function() _preferencesProvider;

  /// ガイドを自動表示済みかどうかの保存キー。
  static const String guideShownKey = 'usage_guide_shown';

  /// まだ一度もガイドを自動表示していなければ true。
  Future<bool> shouldShowGuide() async {
    final prefs = await _preferencesProvider();
    return prefs.getBool(guideShownKey) != true;
  }

  /// ガイドを自動表示済みとして記録する。
  Future<void> markGuideShown() async {
    final prefs = await _preferencesProvider();
    await prefs.setBool(guideShownKey, true);
  }
}
