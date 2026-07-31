import 'package:afterglow_app/widgets/usage_guide_view.dart';
import 'package:flutter/material.dart';

/// 初回起動で自動表示する使い方ガイドのダイアログ（Issue #47）。
///
/// 新規ユーザーが「自分の投稿がどこで見られるか」を知らないまま迷わないよう、
/// 最初の 1 回だけ主要な使い方を案内する。
class UsageGuideDialog extends StatelessWidget {
  const UsageGuideDialog({super.key});

  /// ダイアログを表示する。閉じられると解決する。
  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (_) => const UsageGuideDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.help_outline, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          const Expanded(child: Text('Afterglow の使い方')),
        ],
      ),
      content: const SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(child: UsageGuideView()),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('はじめる'),
        ),
      ],
    );
  }
}
