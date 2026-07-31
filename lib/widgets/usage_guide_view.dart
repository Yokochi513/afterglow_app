import 'package:flutter/material.dart';

/// 使い方ガイド 1 項目分の内容（アイコン・見出し・説明）。
class UsageGuideSection {
  const UsageGuideSection({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;
}

/// 使い方ガイドの本文（Issue #47）。
///
/// 初回起動のダイアログ（[UsageGuideDialog]）と、メニューから開く
/// [UsageGuidePage] の両方で同じ内容を使うためウィジェットに切り出している。
class UsageGuideView extends StatelessWidget {
  const UsageGuideView({super.key});

  /// ガイドに載せる項目。「自分の投稿を見る」は Issue #47 の主目的のため、
  /// 投稿の作り方の次（上のほう）に置く。
  static const List<UsageGuideSection> sections = <UsageGuideSection>[
    UsageGuideSection(
      icon: Icons.map_outlined,
      title: '地図から投稿する',
      description:
          '地図の好きな場所をタップすると、画面下に「ここに投稿」の確認バーが出ます。'
          '写真とコメントを添えて投稿すると、その場所にピンが立ちます。',
    ),
    UsageGuideSection(
      icon: Icons.account_circle,
      title: '自分の投稿を見る・編集する',
      description:
          '画面右上のプロフィールボタン（人型のアイコン）を押すと、自分が投稿した写真が'
          '一覧で並びます。写真をタップすると投稿の詳細が開き、鉛筆アイコンで編集、'
          'ゴミ箱アイコンで削除できます。',
    ),
    UsageGuideSection(
      icon: Icons.dynamic_feed_outlined,
      title: 'みんなの投稿を見る',
      description:
          '地図のピンをタップすると、その投稿の要約が開きます。'
          '画面下の「Feed」タブでは、みんなの投稿を新しい順に読めます。',
    ),
    UsageGuideSection(
      icon: Icons.favorite_border,
      title: 'いいね・コメント',
      description: '投稿には「いいね」とコメントを付けられます。自分のコメントはあとから編集・削除できます。',
    ),
    UsageGuideSection(
      icon: Icons.photo_album_outlined,
      title: 'アルバムとイベント',
      description:
          '「Album」タブでは複数の投稿をひとつのアルバムにまとめられます。'
          '「Event」タブではみんなで集まる予定を共有できます。',
    ),
    UsageGuideSection(
      icon: Icons.campaign_outlined,
      title: 'お知らせとフィードバック',
      description:
          '画面右上のスピーカーアイコンから、アプリの更新内容を確認できます。'
          'ご意見・ご要望はその左のフィードバックボタンから送れます。',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final section in sections) ...[
          _UsageGuideEntry(section: section),
          const SizedBox(height: 20),
        ],
        Text(
          'このガイドは、地図画面の右上にある「使い方」ボタンからいつでも開けます。',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.outline,
          ),
        ),
      ],
    );
  }
}

/// ガイド 1 項目の見た目（アイコン＋見出し＋説明）。
class _UsageGuideEntry extends StatelessWidget {
  const _UsageGuideEntry({required this.section});

  final UsageGuideSection section;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(section.icon, color: theme.colorScheme.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                section.title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(section.description, style: theme.textTheme.bodyMedium),
            ],
          ),
        ),
      ],
    );
  }
}
