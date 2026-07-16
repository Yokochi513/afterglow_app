import 'package:afterglow_app/services/release_note_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _changelog = '''
## [Unreleased]

### Added

- 未リリース。

## [1.1.0+2] - 2026-07-01

### Added

- 新機能A。

## [1.0.0+1] - 2026-06-26

### Fixed

- 修正B。
''';

ReleaseNoteService _service({
  String version = '1.1.0',
  String buildNumber = '2',
  String changelog = _changelog,
}) {
  return ReleaseNoteService(
    loadChangelog: () async => changelog,
    packageInfoProvider: () async => PackageInfo(
      appName: 'afterglow',
      packageName: 'com.afterglow_app.app',
      version: version,
      buildNumber: buildNumber,
    ),
    preferencesProvider: SharedPreferences.getInstance,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('currentVersion', () {
    test('version と buildNumber を CHANGELOG 形式に結合する', () async {
      expect(await _service().currentVersion(), '1.1.0+2');
    });
  });

  group('announcementNote', () {
    test('実行中バージョンに一致するノートを返す', () async {
      final note = await _service(
        version: '1.0.0',
        buildNumber: '1',
      ).announcementNote();

      expect(note?.version, '1.0.0+1');
      expect(note?.sections.first.category, 'Fixed');
    });

    test('一致するノートがなければ最新ノートにフォールバックする', () async {
      final note = await _service(
        version: '9.9.9',
        buildNumber: '9',
      ).announcementNote();

      expect(note?.version, '1.1.0+2');
    });

    test('リリースノートが無ければ null を返す', () async {
      final note = await _service(changelog: '# 変更履歴\n').announcementNote();

      expect(note, isNull);
    });
  });

  group('shouldAnnounce / markAnnounced', () {
    test('未読なら true、記録後は false になる', () async {
      final service = _service();

      expect(await service.shouldAnnounce(), isTrue);

      await service.markAnnounced();

      expect(await service.shouldAnnounce(), isFalse);
    });

    test('バージョンが変わると再び true になる', () async {
      await _service(version: '1.0.0', buildNumber: '1').markAnnounced();

      // 別バージョンで起動したとみなす
      expect(
        await _service(version: '1.1.0', buildNumber: '2').shouldAnnounce(),
        isTrue,
      );
    });
  });
}
