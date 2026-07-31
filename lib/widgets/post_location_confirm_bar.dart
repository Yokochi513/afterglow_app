import 'package:flutter/material.dart';

/// 地図で選んだ投稿位置の確認バー（Issue #36）。
/// 「ここに投稿」で投稿ダイアログへ進み、「キャンセル」で選択を解除する。
/// 位置の取り直し（地図の再タップでマーカーを動かす）は呼び出し側が扱う。
class PostLocationConfirmBar extends StatelessWidget {
  const PostLocationConfirmBar({
    super.key,
    required this.onConfirm,
    required this.onCancel,
  });

  /// 「ここに投稿」押下時に呼ばれる。
  final VoidCallback onConfirm;

  /// 「キャンセル」押下時に呼ばれる。
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 8,
      color: Theme.of(context).colorScheme.surface,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('この場所に投稿しますか？'),
              const SizedBox(height: 2),
              Text(
                '地図をタップすると位置を選び直せます',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(onPressed: onCancel, child: const Text('キャンセル')),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: onConfirm,
                    icon: const Icon(Icons.add_a_photo),
                    label: const Text('ここに投稿'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
