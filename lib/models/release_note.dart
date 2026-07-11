/// 1 バージョン分のリリースノート。CHANGELOG.md（Keep a Changelog 形式）の
/// 1 つの `## [version] - date` セクションに対応するイミュータブルなデータ。
class ReleaseNote {
  const ReleaseNote({
    required this.version,
    this.date,
    this.sections = const [],
  });

  /// バージョン表記（例: `1.0.0+1`）。`pubspec.yaml` の version と一致する。
  final String version;

  /// リリース日（例: `2026-06-26`）。未記載なら null。
  final String? date;

  /// カテゴリー別（Added / Fixed など）の変更内容。
  final List<ReleaseNoteSection> sections;

  /// 表示すべき変更項目を持つか。説明文だけのバージョンを弾くのに使う。
  bool get hasChanges => sections.any((section) => section.items.isNotEmpty);

  /// CHANGELOG.md 全文をパースし、記載順（新しい順）のリリースノート一覧を返す。
  /// `[Unreleased]` セクションと、末尾のリンク参照行は除外する。
  static List<ReleaseNote> parseChangelog(String markdown) {
    final notes = <ReleaseNote>[];

    _ReleaseNoteBuilder? current;

    void commit() {
      if (current != null) {
        notes.add(current!.build());
        current = null;
      }
    }

    for (final rawLine in markdown.split('\n')) {
      final line = rawLine.trimRight();

      if (line.startsWith('## ')) {
        commit();
        final header = _parseVersionHeader(line.substring(3).trim());
        // 未リリース分（Unreleased）は自動お知らせ・履歴の対象外
        if (header == null) {
          current = null;
          continue;
        }
        current = _ReleaseNoteBuilder(
          version: header.version,
          date: header.date,
        );
      } else if (current != null && line.startsWith('### ')) {
        current!.startSection(line.substring(4).trim());
      } else if (current != null && _isBullet(line)) {
        current!.addItem(line.replaceFirst(_bulletPattern, '').trim());
      }
    }
    commit();

    return notes;
  }

  static final RegExp _bulletPattern = RegExp(r'^\s*[-*]\s+');

  static bool _isBullet(String line) => _bulletPattern.hasMatch(line);

  /// `[1.0.0+1] - 2026-06-26` のような見出しを分解する。
  /// `[Unreleased]` は null を返す。
  static _VersionHeader? _parseVersionHeader(String header) {
    final match = RegExp(r'^\[([^\]]+)\](?:\s*-\s*(.+))?$').firstMatch(header);
    if (match == null) return null;
    final version = match.group(1)!.trim();
    if (version.toLowerCase() == 'unreleased') return null;
    final date = match.group(2)?.trim();
    return _VersionHeader(version, date == null || date.isEmpty ? null : date);
  }
}

/// リリースノート内のカテゴリー 1 つ分（例: Added とその項目一覧）。
class ReleaseNoteSection {
  const ReleaseNoteSection({required this.category, this.items = const []});

  /// CHANGELOG のカテゴリー名（`Added` / `Changed` / `Fixed` など）。
  final String category;

  /// カテゴリー配下の変更項目。
  final List<String> items;
}

class _VersionHeader {
  const _VersionHeader(this.version, this.date);
  final String version;
  final String? date;
}

/// パース途中の可変状態を保持し、最後にイミュータブルな [ReleaseNote] を組み立てる。
class _ReleaseNoteBuilder {
  _ReleaseNoteBuilder({required this.version, this.date});

  final String version;
  final String? date;
  final List<ReleaseNoteSection> _sections = [];
  String? _category;
  List<String> _items = [];

  void startSection(String category) {
    _commitSection();
    _category = category;
    _items = [];
  }

  void addItem(String item) {
    if (_category == null || item.isEmpty) return;
    _items.add(item);
  }

  void _commitSection() {
    if (_category != null && _items.isNotEmpty) {
      _sections.add(
        ReleaseNoteSection(
          category: _category!,
          items: List.unmodifiable(_items),
        ),
      );
    }
    _category = null;
    _items = [];
  }

  ReleaseNote build() {
    _commitSection();
    return ReleaseNote(
      version: version,
      date: date,
      sections: List.unmodifiable(_sections),
    );
  }
}
