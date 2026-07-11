import 'package:afterglow_app/models/release_note.dart';
import 'package:afterglow_app/widgets/release_note_view.dart';
import 'package:flutter/material.dart';

/// 1 バージョン分のリリースノートを知らせるダイアログ。
/// 更新後の初回起動で自動表示する「What's New」用。
class ReleaseNoteDialog extends StatelessWidget {
  const ReleaseNoteDialog({super.key, required this.releaseNote});

  final ReleaseNote releaseNote;

  /// ダイアログを表示する。閉じられると解決する。
  static Future<void> show(BuildContext context, ReleaseNote releaseNote) {
    return showDialog<void>(
      context: context,
      builder: (_) => ReleaseNoteDialog(releaseNote: releaseNote),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.campaign_outlined, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          const Expanded(child: Text('新しくなりました')),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'バージョン ${releaseNote.version}'
                '${releaseNote.date != null ? '（${releaseNote.date}）' : ''}',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
              const SizedBox(height: 12),
              ReleaseNoteView(releaseNote: releaseNote),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('閉じる'),
        ),
      ],
    );
  }
}
