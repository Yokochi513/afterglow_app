import 'package:afterglow_app/models/post.dart';
import 'package:afterglow_app/services/auth_service.dart';
import 'package:afterglow_app/services/post_service.dart';
import 'package:afterglow_app/services/user_service.dart';
import 'package:afterglow_app/widgets/post_detail_view.dart';
import 'package:flutter/material.dart';

/// 投稿サマリーの Dialog 表示。地図（MapScreen）のマーカータップから開く。
///
/// 地図はピンをプロットする性質上、写真をパッと見られない。そのためピンを
/// 押したときに「どんな写真が撮られているか」「コメントは」「いいね数は」を
/// 素早く確認できる軽量表示に絞る（[PostViewMode.summary]）。場所は地図が
/// 既に示しているので地図ミニプレビューは出さず、編集/削除もここでは扱わない。
///
/// より詳しく見たい・編集したいときは [onOpenDetail] から `PostDetailPage`
/// （[PostViewMode.full]）へ送る。
class PostCardView extends StatelessWidget {
  const PostCardView(
    this.post, {
    super.key,
    this.authService,
    this.postService,
    this.userService,
    this.reactionBar,
    this.commentSection,
    this.onOpenDetail,
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

  /// 「詳細を見る」の押下時に呼ばれる。未指定なら導線を出さない。
  final VoidCallback? onOpenDetail;

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
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Expanded ではなく Flexible。内容が短いときに Dialog が
                // maxHeight いっぱいに伸びないようにする。
                Flexible(
                  child: PostDetailView(
                    post,
                    mode: PostViewMode.summary,
                    authService: authService,
                    postService: postService,
                    userService: userService,
                    reactionBar: reactionBar,
                    commentSection: commentSection,
                  ),
                ),
                if (onOpenDetail != null) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: onOpenDetail,
                      icon: const Icon(Icons.open_in_new, size: 18),
                      label: const Text('詳細を見る'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
