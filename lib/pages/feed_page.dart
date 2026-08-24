import 'dart:async';

import 'package:afterglow_app/models/post.dart';
import 'package:afterglow_app/pages/post_detail_page.dart';
import 'package:afterglow_app/services/auth_service.dart';
import 'package:afterglow_app/services/comment_service.dart';
import 'package:afterglow_app/services/post_service.dart';
import 'package:afterglow_app/services/reaction_service.dart';
import 'package:afterglow_app/services/user_service.dart';
import 'package:afterglow_app/widgets/comment_section.dart';
import 'package:afterglow_app/widgets/post_card.dart';
import 'package:afterglow_app/widgets/reaction_bar.dart';
import 'package:flutter/material.dart';

/// フィードページ（FR_02 / §5.3）。
///
/// 最新投稿順の [ListView] を表示する。先頭ページ（[PostService.feedPageSize] 件）は
/// Stream で購読して新規投稿をリアルタイムに反映し、スクロール末端で
/// `startAfterDocument` による追加取得を行う（§8.2 / NFR_02）。
class FeedPage extends StatefulWidget {
  const FeedPage({
    super.key,
    this.postService,
    this.userService,
    this.authService,
    this.reactionService,
    this.commentService,
  });

  /// テスト時に差し替え可能。null の場合はビルド時に既定インスタンスを生成する。
  final PostService? postService;
  final UserService? userService;

  /// [ReactionBar] へ渡す。テスト時に差し替え可能。
  final AuthService? authService;
  final ReactionService? reactionService;

  /// [PostCard] のコメント数表示と [CommentSection] へ渡す。テスト時に差し替え可能。
  final CommentService? commentService;

  @override
  State<FeedPage> createState() => _FeedPageState();
}

class _FeedPageState extends State<FeedPage> {
  /// 末端から何ピクセル手前で追加読み込みを開始するか。
  static const double _loadMoreThreshold = 300;

  late final PostService _postService = widget.postService ?? PostService();

  final ScrollController _scrollController = ScrollController();

  StreamSubscription<PostPage>? _firstPageSubscription;

  /// 購読中の先頭ページ（最新 20 件）。
  PostPage? _firstPage;

  /// 無限スクロールで追加取得した 2 ページ目以降の投稿。
  final List<Post> _olderPosts = [];

  /// 最後に読み込んだページ。次ページ取得のカーソル（`lastDocument`）を保持する。
  PostPage? _cursorPage;

  bool _isLoadingMore = false;
  bool _hasMore = true;
  Object? _error;

  /// 表示する投稿一覧。先頭ページが再取得で重複しても ID で除外する。
  List<Post> get _posts {
    final firstPagePosts = _firstPage?.posts ?? const <Post>[];
    final firstPageIds = firstPagePosts.map((post) => post.id).toSet();
    return [
      ...firstPagePosts,
      ..._olderPosts.where((post) => !firstPageIds.contains(post.id)),
    ];
  }

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _firstPageSubscription = _postService.watchPosts().listen(
      (page) {
        if (!mounted) return;
        setState(() {
          _firstPage = page;
          _error = null;
          // 追加取得を一度も行っていない間は、先頭ページの状態を続きの有無とする。
          if (_olderPosts.isEmpty) {
            _cursorPage = page;
            _hasMore = page.hasMore;
          }
        });
      },
      onError: (Object error) {
        if (!mounted) return;
        setState(() => _error = error);
      },
    );
  }

  @override
  void dispose() {
    _firstPageSubscription?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - _loadMoreThreshold) {
      unawaited(_loadMore());
    }
  }

  /// スクロール末端で次ページを取得して末尾に追加する（§8.2）。
  Future<void> _loadMore() async {
    final cursor = _cursorPage?.lastDocument;
    if (_isLoadingMore || !_hasMore || cursor == null) return;

    setState(() => _isLoadingMore = true);
    try {
      final page = await _postService.getPostsPage(startAfter: cursor);
      if (!mounted) return;
      setState(() {
        _olderPosts.addAll(page.posts);
        // 空ページならカーソルは据え置き（hasMore が false になり以降呼ばれない）。
        if (page.lastDocument != null) {
          _cursorPage = page;
        }
        _hasMore = page.hasMore;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error);
    } finally {
      if (mounted) {
        setState(() => _isLoadingMore = false);
      }
    }
  }

  void _openDetail(Post post) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => PostDetailPage(
          post,
          reactionBar: ReactionBar(
            post: post,
            authService: widget.authService,
            reactionService: widget.reactionService,
          ),
          commentSection: CommentSection(
            post: post,
            authService: widget.authService,
            userService: widget.userService,
            commentService: widget.commentService,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Feed')),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_error != null) {
      return Center(child: Text('投稿を読み込めませんでした：$_error'));
    }

    // 先頭ページの初回スナップショット待ち。
    if (_firstPage == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final posts = _posts;
    if (posts.isEmpty) {
      return const Center(child: Text('まだ投稿がありません'));
    }

    return ListView.builder(
      controller: _scrollController,
      // 末尾の 1 件は追加読み込み中のインジケータ。
      itemCount: posts.length + (_isLoadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= posts.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final post = posts[index];
        return PostCard(
          post,
          key: ValueKey(post.id),
          userService: widget.userService,
          authService: widget.authService,
          reactionService: widget.reactionService,
          commentService: widget.commentService,
          onTap: () => _openDetail(post),
        );
      },
    );
  }
}
