import 'package:afterglow_app/widgets/usage_guide_view.dart';
import 'package:flutter/material.dart';

/// 使い方ガイドの一覧画面（Issue #47）。地図画面のメニューから手動で開く。
///
/// 初回起動のダイアログを閉じたあとでも、いつでも同じ内容を読み返せるようにする。
class UsageGuidePage extends StatelessWidget {
  const UsageGuidePage({super.key});

  /// この画面を開く。
  static Future<void> open(BuildContext context) {
    return Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const UsageGuidePage()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('使い方ガイド')),
      body: const SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: UsageGuideView(),
      ),
    );
  }
}
