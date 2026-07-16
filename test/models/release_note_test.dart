import 'package:afterglow_app/models/release_note.dart';
import 'package:flutter_test/flutter_test.dart';

const _sampleChangelog = '''
# 変更履歴

## [Unreleased]

### Added

- 未リリースの新機能。

## [1.1.0+2] - 2026-07-01

説明文の段落。項目としては拾わない。

### Added

- 地図のクラスタリング。
- `flutter_markdown` 表示（バッククォート付き）。

### Fixed

- ピンのズレを修正。

## [1.0.0+1] - 2026-06-26

### Security

- 承認済みユーザーのみ許可。

[Unreleased]: https://example.com/compare
[1.0.0+1]: https://example.com/tag
''';

void main() {
  group('ReleaseNote.parseChangelog', () {
    test('未リリースとリンク参照を除き、記載順にパースする', () {
      final notes = ReleaseNote.parseChangelog(_sampleChangelog);

      expect(notes.map((n) => n.version), ['1.1.0+2', '1.0.0+1']);
    });

    test('バージョン見出しから日付を取り出す', () {
      final notes = ReleaseNote.parseChangelog(_sampleChangelog);

      expect(notes.first.date, '2026-07-01');
      expect(notes[1].date, '2026-06-26');
    });

    test('カテゴリーと項目を対応付け、説明文の段落は項目にしない', () {
      final note = ReleaseNote.parseChangelog(_sampleChangelog).first;

      expect(note.sections.map((s) => s.category), ['Added', 'Fixed']);
      final added = note.sections.first;
      expect(added.items, ['地図のクラスタリング。', '`flutter_markdown` 表示（バッククォート付き）。']);
      expect(note.sections[1].items, ['ピンのズレを修正。']);
    });

    test('hasChanges は項目の有無を反映する', () {
      final notes = ReleaseNote.parseChangelog(_sampleChangelog);

      expect(notes.every((n) => n.hasChanges), isTrue);
      expect(const ReleaseNote(version: '9.9.9').hasChanges, isFalse);
    });

    test('空文字列では空のリストを返す', () {
      expect(ReleaseNote.parseChangelog(''), isEmpty);
    });

    test('項目リストは変更不可（イミュータブル）', () {
      final added = ReleaseNote.parseChangelog(
        _sampleChangelog,
      ).first.sections.first;

      expect(() => added.items.add('x'), throwsUnsupportedError);
    });
  });
}
