import 'package:afterglow_app/models/post.dart';
import 'package:afterglow_app/services/auth_service.dart';
import 'package:afterglow_app/services/post_service.dart';
import 'package:afterglow_app/services/user_service.dart';
import 'package:afterglow_app/widgets/post_detail_view.dart';
import 'package:flutter/material.dart';

/// 投稿詳細ページ（FR_04 / §5.6）。フィード・プロフィールから push で開く。
///
/// フィード（一覧）で気に入った写真について「どこで撮られたのか」まで
/// 見られるのが利点なので、[PostViewMode.full] で場所名 + 地図ミニプレビューを
/// 出し、自投稿なら編集/削除もここで行う。
///
/// 中身は [PostDetailView] と共通で、ここではフルページとしての体裁
/// （AppBar・最大幅・余白）だけを与える。地図のマーカータップからは
/// 同じ中身を [PostCardView] が Dialog + [PostViewMode.summary] の軽量表示で
/// 見せる。
///
/// Dialog と違って一画面まるまる使えるので幅を絞らず、ワイド画面では
/// [PostDetailView] が写真と情報の 2 カラムに切り替わる。
class PostDetailPage extends StatelessWidget {
  /// 超ワイドディスプレイで説明文やコメントが横に伸びすぎないための上限。
  /// 2 カラムを成立させたうえで読みやすさを保てる幅として置いている。
  static const double _maxContentWidth = 1400;

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
            constraints: const BoxConstraints(maxWidth: _maxContentWidth),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
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
