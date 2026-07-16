import 'package:afterglow_app/models/release_note.dart';
import 'package:flutter/material.dart';

/// CHANGELOG のカテゴリー名（英語）を日本語ラベルに対応付ける。
/// 未知のカテゴリーはそのまま表示する。
String releaseNoteCategoryLabel(String category) {
  switch (category.toLowerCase()) {
    case 'added':
      return '新機能';
    case 'changed':
      return '変更';
    case 'deprecated':
      return '非推奨';
    case 'removed':
      return '削除';
    case 'fixed':
      return '修正';
    case 'security':
      return 'セキュリティ';
    default:
      return category;
  }
}

/// カテゴリーに対応するアイコン。
IconData releaseNoteCategoryIcon(String category) {
  switch (category.toLowerCase()) {
    case 'added':
      return Icons.add_circle_outline;
    case 'changed':
      return Icons.tune;
    case 'deprecated':
      return Icons.schedule;
    case 'removed':
      return Icons.remove_circle_outline;
    case 'fixed':
      return Icons.build_outlined;
    case 'security':
      return Icons.shield_outlined;
    default:
      return Icons.circle_outlined;
  }
}

/// 1 バージョン分のリリースノート本文（カテゴリー別の変更項目一覧）を描画する。
/// ダイアログ・一覧ページの両方から再利用する。バージョン見出しは含めない。
class ReleaseNoteView extends StatelessWidget {
  const ReleaseNoteView({super.key, required this.releaseNote});

  final ReleaseNote releaseNote;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final section in releaseNote.sections)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Icon(
                      releaseNoteCategoryIcon(section.category),
                      size: 18,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      releaseNoteCategoryLabel(section.category),
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                for (final item in section.items)
                  Padding(
                    padding: const EdgeInsets.only(left: 24, top: 2),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('・'),
                        Expanded(
                          child: Text(item, style: theme.textTheme.bodyMedium),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
