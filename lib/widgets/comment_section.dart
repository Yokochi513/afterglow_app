import 'package:afterglow_app/models/app_user.dart';
import 'package:afterglow_app/models/comment.dart';
import 'package:afterglow_app/models/post.dart';
import 'package:afterglow_app/pages/profile_page.dart';
import 'package:afterglow_app/services/auth_service.dart';
import 'package:afterglow_app/services/comment_service.dart';
import 'package:afterglow_app/services/user_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// コメント一覧 + 投稿フォーム（PS_05 / #12）。
/// [PostDetailView] のコメントスロットに差し込んで使う。
///
/// コメントはテキストのみ。各コメントには投稿者のアイコン/名前を表示し、
/// タップで [ProfilePage] へ遷移する。自分のコメントのみ編集・削除できる。
class CommentSection extends StatefulWidget {
  const CommentSection({
    super.key,
    required this.post,
    this.authService,
    this.userService,
    this.commentService,
  });

  final Post post;

  /// テスト時に差し替え可能。null の場合はビルド時に既定インスタンスを生成する。
  final AuthService? authService;
  final UserService? userService;
  final CommentService? commentService;

  @override
  State<CommentSection> createState() => _CommentSectionState();
}

class _CommentSectionState extends State<CommentSection> {
  late final AuthService _authService = widget.authService ?? AuthService();
  late final UserService _userService = widget.userService ?? UserService();
  late final CommentService _commentService =
      widget.commentService ?? CommentService();

  final TextEditingController _inputController = TextEditingController();

  bool _isSubmitting = false;

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  /// 新規コメントを投稿する。空文字・未ログインの場合は何もしない。
  Future<void> _submit() async {
    final text = _inputController.text.trim();
    final uid = _authService.currentUserId;
    if (text.isEmpty || uid == null) {
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    setState(() => _isSubmitting = true);

    final success = await _commentService.addComment(
      Comment(
        id: '',
        postId: widget.post.id,
        userId: uid,
        text: text,
        createdAt: DateTime.now(),
      ),
    );

    if (!mounted) {
      return;
    }

    setState(() => _isSubmitting = false);

    if (success) {
      _inputController.clear();
      FocusScope.of(context).unfocus();
    } else {
      messenger.showSnackBar(const SnackBar(content: Text('コメントの送信に失敗しました')));
    }
  }

  /// 自コメントの編集ダイアログを開き、変更があれば更新する（PS_05）。
  Future<void> _editComment(Comment comment) async {
    final controller = TextEditingController(text: comment.text);
    final messenger = ScaffoldMessenger.of(context);

    final newText = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('コメントを編集'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: null,
          minLines: 1,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            hintText: 'コメントを入力',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('保存'),
          ),
        ],
      ),
    );

    controller.dispose();

    if (newText == null || newText.isEmpty || newText == comment.text) {
      return;
    }

    final success = await _commentService.updateComment(
      widget.post.id,
      comment.id,
      newText,
    );

    if (!mounted) {
      return;
    }

    if (!success) {
      messenger.showSnackBar(const SnackBar(content: Text('コメントの更新に失敗しました')));
    }
  }

  /// 自コメントの削除確認ダイアログを開き、承認されれば削除する（PS_05）。
  Future<void> _deleteComment(Comment comment) async {
    final messenger = ScaffoldMessenger.of(context);

    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('コメントを削除'),
        content: const Text('このコメントを削除しますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('削除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (shouldDelete != true) {
      return;
    }

    final success = await _commentService.deleteComment(
      widget.post.id,
      comment.id,
    );

    if (!mounted) {
      return;
    }

    if (!success) {
      messenger.showSnackBar(const SnackBar(content: Text('コメントの削除に失敗しました')));
    }
  }

  void _openProfile(String userId) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => ProfilePage(userId: userId)),
    );
  }

  /// `2026/07/15 21:30` 形式の日時文字列。intl を導入せずに整形する。
  String _formatTimestamp(DateTime time) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${time.year}/${two(time.month)}/${two(time.day)} '
        '${two(time.hour)}:${two(time.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('コメント', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        StreamBuilder<List<Comment>>(
          stream: _commentService.getComments(widget.post.id),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: CircularProgressIndicator()),
              );
            }

            final comments = snapshot.data ?? const <Comment>[];
            if (comments.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'まだコメントはありません',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
                ),
              );
            }

            return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: comments.length,
              separatorBuilder: (_, _) => const Divider(height: 16),
              itemBuilder: (context, index) =>
                  _buildCommentTile(comments[index]),
            );
          },
        ),
        const SizedBox(height: 12),
        _buildInputField(),
      ],
    );
  }

  Widget _buildCommentTile(Comment comment) {
    final isOwn = _authService.currentUserId == comment.userId;

    return StreamBuilder<AppUser?>(
      stream: _userService.watchUser(comment.userId),
      builder: (context, snapshot) {
        final author = snapshot.data;
        final hasImage = (author?.profileImageUrl ?? '').isNotEmpty;
        final username = (author?.username ?? '').isNotEmpty
            ? author!.username
            : '不明なユーザー';

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: () => _openProfile(comment.userId),
              borderRadius: BorderRadius.circular(16),
              child: CircleAvatar(
                radius: 16,
                backgroundColor: Colors.grey.shade200,
                backgroundImage: hasImage
                    ? CachedNetworkImageProvider(author!.profileImageUrl!)
                    : null,
                child: hasImage
                    ? null
                    : const Icon(Icons.person, size: 18, color: Colors.grey),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: InkWell(
                          onTap: () => _openProfile(comment.userId),
                          child: Text(
                            username,
                            style: Theme.of(context).textTheme.titleSmall,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _formatTimestamp(
                          comment.updatedAt ?? comment.createdAt,
                        ),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey.shade600,
                        ),
                      ),
                      if (comment.updatedAt != null) ...[
                        const SizedBox(width: 4),
                        Text(
                          '(編集済み)',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: Colors.grey.shade600),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(comment.text),
                ],
              ),
            ),
            // 自分のコメントにのみ編集・削除メニューを表示する（PS_05）。
            if (isOwn)
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_horiz, size: 20),
                tooltip: 'コメントの操作',
                onSelected: (value) {
                  if (value == 'edit') {
                    _editComment(comment);
                  } else if (value == 'delete') {
                    _deleteComment(comment);
                  }
                },
                itemBuilder: (context) => const [
                  PopupMenuItem<String>(value: 'edit', child: Text('編集')),
                  PopupMenuItem<String>(value: 'delete', child: Text('削除')),
                ],
              ),
          ],
        );
      },
    );
  }

  Widget _buildInputField() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: TextField(
            controller: _inputController,
            minLines: 1,
            maxLines: 4,
            textInputAction: TextInputAction.newline,
            decoration: const InputDecoration(
              hintText: 'コメントを追加...',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
        ),
        const SizedBox(width: 8),
        _isSubmitting
            ? const Padding(
                padding: EdgeInsets.all(8),
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            : IconButton(
                onPressed: _submit,
                icon: const Icon(Icons.send),
                tooltip: 'コメントを送信',
              ),
      ],
    );
  }
}
