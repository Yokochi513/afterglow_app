import 'package:afterglow_app/models/album.dart';
import 'package:afterglow_app/models/app_user.dart';
import 'package:afterglow_app/pages/album_detail_page.dart';
import 'package:afterglow_app/services/album_service.dart';
import 'package:afterglow_app/services/user_service.dart';
import 'package:afterglow_app/widgets/album_edit_dialog.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// アルバム一覧画面（PS_02 / §3.6）。
///
/// **表示範囲は「全体」**：承認済みユーザー全員のアルバムを新しい順に表示する。
/// メンバー間で撮影会・テーマごとの写真を共有する PS_02 の目的に沿った範囲で、
/// Firestore ルール（read は承認済みユーザー / write は所有者のみ・§7.2）とも
/// 一致する。作成は誰でも行え、編集・削除は所有者のみ（[AlbumDetailPage]）。
class AlbumListPage extends StatelessWidget {
  const AlbumListPage({super.key});

  @override
  Widget build(BuildContext context) {
    final albumService = AlbumService();

    return Scaffold(
      appBar: AppBar(title: const Text('アルバム')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => showDialog<bool>(
          context: context,
          builder: (_) => const AlbumEditDialog(),
        ),
        tooltip: 'アルバムを作成',
        child: const Icon(Icons.add),
      ),
      body: StreamBuilder<List<Album>>(
        stream: albumService.getAlbums(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final albums = snapshot.data ?? [];
          if (albums.isEmpty) {
            return const Center(child: Text('まだアルバムがありません'));
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: albums.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) => _AlbumTile(album: albums[index]),
          );
        },
      ),
    );
  }
}

/// 一覧の 1 行。カバー画像・タイトル・所有者名・投稿数を表示する。
class _AlbumTile extends StatelessWidget {
  const _AlbumTile({required this.album});

  final Album album;

  @override
  Widget build(BuildContext context) {
    final userService = UserService();
    final coverUrl = album.coverImageUrl;

    return ListTile(
      leading: SizedBox(
        width: 56,
        height: 56,
        child: coverUrl == null || coverUrl.isEmpty
            ? Container(
                color: Colors.grey.shade200,
                child: const Icon(
                  Icons.photo_album_outlined,
                  color: Colors.grey,
                ),
              )
            : CachedNetworkImage(
                imageUrl: coverUrl,
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
      ),
      title: Text(album.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: StreamBuilder<AppUser?>(
        stream: userService.watchUser(album.ownerId),
        builder: (context, snapshot) {
          final username = snapshot.data?.username ?? '';
          return Text(
            '${username.isEmpty ? '名無しさん' : username}・${album.postIds.length}件',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          );
        },
      ),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => AlbumDetailPage(albumId: album.id),
        ),
      ),
    );
  }
}
