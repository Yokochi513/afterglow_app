import 'package:afterglow_app/models/post.dart';
import 'package:afterglow_app/services/auth_service.dart';
import 'package:afterglow_app/services/post_service.dart';
import 'package:afterglow_app/services/user_service.dart';
import 'package:afterglow_app/widgets/post_detail_view.dart';
import 'package:flutter/material.dart';

/// 投稿詳細ページ（FR_04 / §5.6）。フィード・プロフィールから push で開く。
///
/// 中身は [PostDetailView] と共通で、ここではフルページとしての体裁
/// （AppBar・最大幅・余白）だけを与える。地図のマーカータップからは
/// 同じ中身を `PostCardView` が Dialog で表示する。
class PostDetailPage extends StatelessWidget {
  const PostDetailPage(
    this.post, {
    super.key,
    this.authService,
    this.postService,
    this.userService,
    this.reactionBar,
    this.commentSection,
  });

  final Post post;

  /// テスト時に差し替え可能。null の場合は [PostDetailView] が既定インスタンスを生成する。
  final AuthService? authService;
  final PostService? postService;
  final UserService? userService;

  /// リアクションバー（#13）の差し込み口。未指定なら表示しない。
  final Widget? reactionBar;

  /// コメントセクション（#12）の差し込み口。未指定なら表示しない。
  final Widget? commentSection;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('投稿')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 630),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              child: PostDetailView(
                post,
                authService: authService,
                postService: postService,
                userService: userService,
                reactionBar: reactionBar,
                commentSection: commentSection,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
