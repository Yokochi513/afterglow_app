import 'package:afterglow_app/models/album.dart';
import 'package:afterglow_app/models/app_user.dart';
import 'package:afterglow_app/models/post.dart';
import 'package:afterglow_app/pages/post_detail_page.dart';
import 'package:afterglow_app/services/album_service.dart';
import 'package:afterglow_app/services/auth_service.dart';
import 'package:afterglow_app/services/post_service.dart';
import 'package:afterglow_app/services/user_service.dart';
import 'package:afterglow_app/widgets/album_edit_dialog.dart';
import 'package:afterglow_app/widgets/comment_section.dart';
import 'package:afterglow_app/widgets/reaction_bar.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// アルバム詳細画面（PS_02 / §3.6）。
///
/// アルバムの情報と、含まれる投稿のグリッドを表示する。閲覧は承認済み
/// ユーザー全員が行えるが、編集・削除・投稿の追加/削除は所有者
/// （`ownerId`）のみに限定する（Firestore ルールでも担保・§7.2）。
class AlbumDetailPage extends StatelessWidget {
  const AlbumDetailPage({super.key, required this.albumId});

  final String albumId;

  @override
  Widget build(BuildContext context) {
    final albumService = AlbumService();
    final currentUid = AuthService().currentUserId;

    return StreamBuilder<Album?>(
      stream: albumService.watchAlbum(albumId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final album = snapshot.data;
        if (album == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: Text('アルバムが見つかりませんでした')),
          );
        }

        final isOwner = albumService.isOwnedBy(album, currentUid);

        return Scaffold(
          appBar: AppBar(
            title: Text(album.title),
            actions: [
              if (isOwner) ...[
                IconButton(
                  icon: const Icon(Icons.edit),
                  tooltip: 'アルバムを編集',
                  onPressed: () => showDialog<bool>(
                    context: context,
                    builder: (_) => AlbumEditDialog(album: album),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  tooltip: 'アルバムを削除',
                  onPressed: () =>
                      _confirmDeleteAlbum(context, albumService, album),
                ),
              ],
            ],
          ),
          floatingActionButton: isOwner
              ? FloatingActionButton(
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (_) => _AlbumPostPickerDialog(album: album),
                  ),
                  tooltip: '投稿を追加',
                  child: const Icon(Icons.add_photo_alternate_outlined),
                )
              : null,
          body: _AlbumBody(album: album, isOwner: isOwner),
        );
      },
    );
  }

  Future<void> _confirmDeleteAlbum(
    BuildContext context,
    AlbumService albumService,
    Album album,
  ) async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('アルバムを削除'),
        content: const Text('このアルバムを削除しますか？\n含まれる投稿自体は削除されません。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('削除'),
          ),
        ],
      ),
    );

    if (shouldDelete != true) {
      return;
    }

    if (await albumService.deleteAlbum(album.id)) {
      // 削除後は詳細画面を維持できないため一覧へ戻る。
      navigator.pop();
      return;
    }
    messenger.showSnackBar(
      const SnackBar(
        content: Text('アルバムの削除に失敗しました'),
        backgroundColor: Colors.red,
      ),
    );
  }
}

class _AlbumBody extends StatelessWidget {
  const _AlbumBody({required this.album, required this.isOwner});

  final Album album;

  /// 所有者なら投稿の追加・削除の導線を表示する。
  final bool isOwner;

  @override
  Widget build(BuildContext context) {
    final userService = UserService();
    final postService = PostService();

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                StreamBuilder<AppUser?>(
                  stream: userService.watchUser(album.ownerId),
                  builder: (context, snapshot) {
                    final username = snapshot.data?.username ?? '';
                    return Text(
                      '作成者: ${username.isEmpty ? '名無しさん' : username}',
                      style: Theme.of(context).textTheme.bodySmall,
                    );
                  },
                ),
                if (album.description.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(album.description),
                ],
                const SizedBox(height: 12),
                Text(
                  '${album.postIds.length}件の投稿',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          FutureBuilder<List<Post>>(
            // postIds が変わるたびに投稿を取り直す。
            key: ValueKey(album.postIds.join(',')),
            future: postService.getPostsByIds(album.postIds),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              final posts = snapshot.data ?? [];
              if (posts.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(32),
                  child: Center(
                    child: Text(
                      isOwner ? 'まだ投稿がありません。＋から追加できます' : 'まだ投稿がありません',
                    ),
                  ),
                );
              }

              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.all(8),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 4,
                  crossAxisSpacing: 4,
                ),
                itemCount: posts.length,
                itemBuilder: (context, index) {
                  final post = posts[index];
                  return _AlbumPostTile(
                    post: post,
                    album: album,
                    isOwner: isOwner,
                  );
                },
              );
            },
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

/// グリッドの 1 枚。タップで投稿詳細、所有者は長押しでアルバムから取り除ける。
class _AlbumPostTile extends StatelessWidget {
  const _AlbumPostTile({
    required this.post,
    required this.album,
    required this.isOwner,
  });

  final Post post;
  final Album album;
  final bool isOwner;

  @override
  Widget build(BuildContext context) {
    final thumbnailUrl = post.imageUrls.isNotEmpty
        ? post.imageUrls.first
        : null;

    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => PostDetailPage(
            post,
            reactionBar: ReactionBar(post: post),
            commentSection: CommentSection(post: post),
          ),
        ),
      ),
      onLongPress: isOwner ? () => _confirmRemovePost(context) : null,
      child: thumbnailUrl == null
          ? Container(
              color: Colors.grey.shade200,
              child: const Icon(
                Icons.image_not_supported_outlined,
                color: Colors.grey,
              ),
            )
          : CachedNetworkImage(
              imageUrl: thumbnailUrl,
              fit: BoxFit.cover,
              placeholder: (_, _) => Container(color: Colors.grey.shade200),
              errorWidget: (_, _, _) => Container(
                color: Colors.grey.shade200,
                child: const Icon(
                  Icons.broken_image_outlined,
                  color: Colors.grey,
                ),
              ),
            ),
    );
  }

  Future<void> _confirmRemovePost(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final shouldRemove = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('アルバムから削除'),
        content: const Text('この投稿をアルバムから取り除きますか？\n投稿自体は削除されません。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('取り除く'),
          ),
        ],
      ),
    );

    if (shouldRemove != true) {
      return;
    }

    // 成功時は albums の購読が流れてグリッドが再構築されるため、失敗時のみ通知する。
    if (!await AlbumService().removePost(album.id, post.id)) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('アルバムからの削除に失敗しました'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

/// 自分の投稿からアルバムに追加する投稿を選ぶダイアログ。
/// 既にアルバムに含まれる投稿はチェック済みで表示し、その場で追加/削除する。
///
/// ダイアログは詳細画面とは別ルートで、親の再構築を受けない。チェック状態を
/// 操作直後に反映させるため、[album] の `postIds` はここでも購読し直す。
class _AlbumPostPickerDialog extends StatelessWidget {
  const _AlbumPostPickerDialog({required this.album});

  final Album album;

  @override
  Widget build(BuildContext context) {
    final albumService = AlbumService();
    final postService = PostService();

    return AlertDialog(
      title: const Text('投稿を追加'),
      content: SizedBox(
        width: 320,
        height: 400,
        child: StreamBuilder<Album?>(
          stream: albumService.watchAlbum(album.id),
          initialData: album,
          builder: (context, albumSnapshot) {
            final postIds = albumSnapshot.data?.postIds ?? album.postIds;

            return StreamBuilder<List<Post>>(
              stream: postService.getUserPosts(album.ownerId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final posts = snapshot.data ?? [];
                if (posts.isEmpty) {
                  return const Center(child: Text('追加できる投稿がありません'));
                }

                return ListView.builder(
                  itemCount: posts.length,
                  itemBuilder: (context, index) {
                    final post = posts[index];
                    final thumbnailUrl = post.imageUrls.isNotEmpty
                        ? post.imageUrls.first
                        : null;

                    return CheckboxListTile(
                      value: postIds.contains(post.id),
                      onChanged: (selected) async {
                        if (selected == true) {
                          await albumService.addPost(album.id, post.id);
                        } else {
                          await albumService.removePost(album.id, post.id);
                        }
                      },
                      secondary: SizedBox(
                        width: 48,
                        height: 48,
                        child: thumbnailUrl == null
                            ? Container(color: Colors.grey.shade200)
                            : CachedNetworkImage(
                                imageUrl: thumbnailUrl,
                                fit: BoxFit.cover,
                                placeholder: (_, _) =>
                                    Container(color: Colors.grey.shade200),
                                errorWidget: (_, _, _) =>
                                    Container(color: Colors.grey.shade200),
                              ),
                      ),
                      title: Text(
                        post.caption.isEmpty ? '(説明なし)' : post.caption,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  },
                );
              },
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('閉じる'),
        ),
      ],
    );
  }
}
