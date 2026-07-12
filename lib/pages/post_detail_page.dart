import 'package:afterglow_app/models/post.dart';
import 'package:afterglow_app/widgets/post_widget.dart';
import 'package:flutter/material.dart';

/// 投稿詳細ページ（FR_04 / §5.6）。
///
/// 現時点では既存の [PostCardView]（画像ギャラリー・投稿者・キャプション・
/// 所有者向け編集/削除）をフルページとしてホストする最小構成。場所名・地図
/// ミニプレビュー・タグ一覧・リアクション/コメントの差し込みは Issue #11 で行う。
class PostDetailPage extends StatelessWidget {
  const PostDetailPage(this.post, {super.key});

  final Post post;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('投稿')),
      body: SafeArea(child: Center(child: PostCardView(post))),
    );
  }
}
