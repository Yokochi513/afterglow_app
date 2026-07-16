import 'package:afterglow_app/models/post.dart';
import 'package:afterglow_app/services/auth_service.dart';
import 'package:afterglow_app/services/reaction_service.dart';
import 'package:afterglow_app/services/user_service.dart';
import 'package:afterglow_app/widgets/reaction_bar.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// フィード（FR_02 / §5.3）の 1 投稿を表すカード。
///
/// サムネイル（先頭画像）・投稿者名・caption・タグ・いいね・コメント数を表示し、
/// タップで [onTap] を呼ぶ。いいねはカード上で直接トグルできる（[ReactionBar]）。
/// 画像は [CachedNetworkImage] でディスクキャッシュする（§8.2）。
class PostCard extends StatefulWidget {
  const PostCard(
    this.post, {
    super.key,
    this.onTap,
    this.userService,
    this.authService,
    this.reactionService,
  });

  final Post post;
  final VoidCallback? onTap;

  /// テスト時に差し替え可能。null の場合はビルド時に既定インスタンスを生成する。
  final UserService? userService;
  final AuthService? authService;
  final ReactionService? reactionService;

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  static const double _thumbnailSize = 96;

  late final UserService _userService = widget.userService ?? UserService();

  @override
  Widget build(BuildContext context) {
    final post = widget.post;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: widget.onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildThumbnail(post),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildAuthorName(post),
                    const SizedBox(height: 4),
                    if (post.caption.isNotEmpty)
                      Text(
                        post.caption,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    if (post.tags.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      _buildTags(post),
                    ],
                    const SizedBox(height: 8),
                    _buildCounts(post),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 先頭画像のサムネイル。画像が無い投稿はプレースホルダを表示する。
  Widget _buildThumbnail(Post post) {
    final imageUrl = post.imageUrls.isEmpty ? null : post.imageUrls.first;

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: _thumbnailSize,
        height: _thumbnailSize,
        child: imageUrl == null
            ? _buildThumbnailPlaceholder(const Icon(Icons.image_not_supported))
            : CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.cover,
                placeholder: (context, url) => _buildThumbnailPlaceholder(
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
                errorWidget: (context, url, error) =>
                    _buildThumbnailPlaceholder(
                      const Icon(Icons.broken_image_outlined),
                    ),
              ),
      ),
    );
  }

  Widget _buildThumbnailPlaceholder(Widget child) {
    return ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Center(child: child),
    );
  }

  /// 投稿者名。users ドキュメントを購読し、取得できるまでは UID を出さず空欄にする。
  Widget _buildAuthorName(Post post) {
    return StreamBuilder(
      stream: _userService.watchUser(post.userId),
      builder: (context, snapshot) {
        final username = snapshot.data?.username ?? '';
        return Text(
          username.isEmpty ? '名無しさん' : username,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
        );
      },
    );
  }

  Widget _buildTags(Post post) {
    return Wrap(
      spacing: 6,
      runSpacing: -8,
      children: post.tags
          .map(
            (tag) => Chip(
              label: Text('#$tag'),
              labelStyle: Theme.of(context).textTheme.labelSmall,
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          )
          .toList(growable: false),
    );
  }

  /// いいね（トグル可能）とコメント数。
  /// コメント数は posts の非正規化フィールドをそのまま表示する。
  Widget _buildCounts(Post post) {
    final style = Theme.of(context).textTheme.labelMedium;

    return Row(
      children: [
        ReactionBar(
          post: post,
          compact: true,
          authService: widget.authService,
          reactionService: widget.reactionService,
        ),
        const SizedBox(width: 16),
        const Icon(Icons.mode_comment_outlined, size: 16),
        const SizedBox(width: 4),
        Text('${post.commentCount}', style: style),
      ],
    );
  }
}
