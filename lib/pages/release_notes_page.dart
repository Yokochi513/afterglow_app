import 'package:afterglow_app/models/release_note.dart';
import 'package:afterglow_app/services/release_note_service.dart';
import 'package:afterglow_app/widgets/release_note_view.dart';
import 'package:flutter/material.dart';

/// リリースお知らせ（変更履歴）の一覧画面。メニューから手動で開く。
///
/// CHANGELOG.md をパースし、バージョンごとの変更内容を新しい順に表示する。
class ReleaseNotesPage extends StatelessWidget {
  const ReleaseNotesPage({super.key, ReleaseNoteService? service})
    : _service = service;

  final ReleaseNoteService? _service;

  @override
  Widget build(BuildContext context) {
    final service = _service ?? ReleaseNoteService();

    return Scaffold(
      appBar: AppBar(title: const Text('お知らせ')),
      body: FutureBuilder<List<ReleaseNote>>(
        future: service.loadReleaseNotes(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text('お知らせを読み込めませんでした'));
          }

          final notes = snapshot.data ?? const [];
          if (notes.isEmpty) {
            return const Center(child: Text('お知らせはまだありません'));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: notes.length,
            separatorBuilder: (_, _) => const Divider(height: 32),
            itemBuilder: (context, index) =>
                _ReleaseNoteEntry(releaseNote: notes[index]),
          );
        },
      ),
    );
  }
}

/// 一覧内の 1 バージョン分（見出し＋本文）。
class _ReleaseNoteEntry extends StatelessWidget {
  const _ReleaseNoteEntry({required this.releaseNote});

  final ReleaseNote releaseNote;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              releaseNote.version,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            if (releaseNote.date != null) ...[
              const SizedBox(width: 8),
              Text(
                releaseNote.date!,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),
        ReleaseNoteView(releaseNote: releaseNote),
      ],
    );
  }
}
