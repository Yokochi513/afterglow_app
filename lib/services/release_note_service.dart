import 'package:afterglow_app/models/release_note.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// アプリ内リリースお知らせ機能のデータ層。
///
/// 同梱した `CHANGELOG.md`（Keep a Changelog 形式）を読み込んでリリースノートに
/// 変換し、実行中アプリのバージョン（`package_info_plus`）と最後にお知らせを
/// 表示したバージョン（`shared_preferences`）を突き合わせて、更新後の初回起動で
/// 自動表示すべきかを判定する。
///
/// テストからモックを注入できるよう、アセット読み込み・バージョン取得・設定
/// ストレージの各依存はコンストラクタで差し替え可能にしている。
class ReleaseNoteService {
  ReleaseNoteService({
    Future<String> Function()? loadChangelog,
    Future<PackageInfo> Function()? packageInfoProvider,
    Future<SharedPreferences> Function()? preferencesProvider,
  }) : _loadChangelog =
           loadChangelog ?? (() => rootBundle.loadString(changelogAsset)),
       _packageInfoProvider = packageInfoProvider ?? PackageInfo.fromPlatform,
       _preferencesProvider =
           preferencesProvider ?? SharedPreferences.getInstance;

  final Future<String> Function() _loadChangelog;
  final Future<PackageInfo> Function() _packageInfoProvider;
  final Future<SharedPreferences> Function() _preferencesProvider;

  /// pubspec.yaml と同じ場所に置いた変更履歴。アセットとして同梱する。
  static const String changelogAsset = 'CHANGELOG.md';

  /// 最後にお知らせを表示したアプリバージョンの保存キー。
  static const String lastSeenVersionKey = 'release_note_last_seen_version';

  /// 実行中アプリのバージョン（`メジャー.マイナー.パッチ+ビルド番号`）。
  /// CHANGELOG の見出し（例: `1.0.0+1`）と一致する形式にそろえる。
  Future<String> currentVersion() async {
    final info = await _packageInfoProvider();
    return '${info.version}+${info.buildNumber}';
  }

  /// CHANGELOG.md をパースし、記載順（新しい順）のリリースノート一覧を返す。
  Future<List<ReleaseNote>> loadReleaseNotes() async {
    final markdown = await _loadChangelog();
    return ReleaseNote.parseChangelog(markdown);
  }

  /// 更新後の初回起動などで自動表示すべきリリースノートを返す。
  /// 実行中バージョンに一致するノートを優先し、なければ最新のノートを使う。
  /// 表示すべき内容がなければ null。
  Future<ReleaseNote?> announcementNote() async {
    final notes = await loadReleaseNotes();
    if (notes.isEmpty) return null;

    final version = await currentVersion();
    final matched = notes.where((note) => note.version == version);
    final note = matched.isNotEmpty ? matched.first : notes.first;
    return note.hasChanges ? note : null;
  }

  /// 実行中バージョンについて、まだお知らせを表示していなければ true。
  Future<bool> shouldAnnounce() async {
    final prefs = await _preferencesProvider();
    final lastSeen = prefs.getString(lastSeenVersionKey);
    final version = await currentVersion();
    return lastSeen != version;
  }

  /// 実行中バージョンをお知らせ済みとして記録する。
  Future<void> markAnnounced() async {
    final prefs = await _preferencesProvider();
    final version = await currentVersion();
    await prefs.setString(lastSeenVersionKey, version);
  }
}
