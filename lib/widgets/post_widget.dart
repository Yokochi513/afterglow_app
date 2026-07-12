import 'package:afterglow_app/models/post.dart';
import 'package:afterglow_app/services/auth_service.dart';
import 'package:afterglow_app/services/post_service.dart';
import 'package:afterglow_app/services/user_service.dart';
import 'package:afterglow_app/widgets/post_detail_view.dart';
import 'package:flutter/material.dart';

/// 投稿詳細の Dialog 表示。地図（MapScreen）のマーカータップから開く。
///
/// 中身は [PostDetailView] と共通で、ここでは Dialog としての体裁
/// （余白・最大サイズ・キーボード回避）だけを与える。フィード・プロフィールからは
/// 同じ中身を `PostDetailPage` がフルページで表示する。
class PostCardView extends StatelessWidget {
  const PostCardView(
    this.post, {
    super.key,
    this.authService,
    this.postService,
    this.userService,
  });

  final Post post;

  /// テスト時に差し替え可能。null の場合は [PostDetailView] が既定インスタンスを生成する。
  final AuthService? authService;
  final PostService? postService;
  final UserService? userService;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 630, maxHeight: 800),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: PostDetailView(
              post,
              authService: authService,
              postService: postService,
              userService: userService,
            ),
          ),
        ),
      ),
    );
  }
}
