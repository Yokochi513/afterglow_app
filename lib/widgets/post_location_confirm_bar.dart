import 'package:flutter/material.dart';

/// 地図で選んだ投稿位置の確認バー（Issue #36）。
/// 既定では「ここに投稿」で投稿ダイアログへ進み、「キャンセル」で選択を解除する。
/// 位置の取り直し（地図の再タップでマーカーを動かす）は呼び出し側が扱う。
/// 文言とアイコンは差し替え可能で、位置の編集（Issue #37）でも使い回す。
class PostLocationConfirmBar extends StatelessWidget {
  const PostLocationConfirmBar({
    super.key,
    required this.onConfirm,
    required this.onCancel,
    this.message = 'この場所に投稿しますか？',
    this.confirmLabel = 'ここに投稿',
    this.confirmIcon = Icons.add_a_photo,
  });

  /// 確定ボタン押下時に呼ばれる。
  final VoidCallback onConfirm;

  /// 「キャンセル」押下時に呼ばれる。
  final VoidCallback onCancel;

  /// 案内文。既定は投稿用の文言。
  final String message;

  /// 確定ボタンのラベル。既定は投稿用の文言。
  final String confirmLabel;

  /// 確定ボタンのアイコン。既定は投稿用のカメラアイコン。
  final IconData confirmIcon;

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
              Text(message),
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
                    icon: Icon(confirmIcon),
                    label: Text(confirmLabel),
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
