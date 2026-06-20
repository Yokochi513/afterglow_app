import 'package:afterglow_app/models/app_user.dart';
import 'package:afterglow_app/models/post.dart';
import 'package:afterglow_app/pages/profile_edit_page.dart';
import 'package:afterglow_app/services/auth_service.dart';
import 'package:afterglow_app/services/post_service.dart';
import 'package:afterglow_app/services/user_service.dart';
import 'package:afterglow_app/widgets/post_widget.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// ログイン中ユーザーのプロフィール画面。
///
/// プロフィール画像・ユーザー名・自己紹介・投稿グリッドを表示し、
/// 編集・ログアウトを行える（FR_06）。
class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();
    final userService = UserService();
    final uid = authService.currentUserId;

    return Scaffold(
      appBar: AppBar(
        title: const Text('プロフィール'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'ログアウト',
            onPressed: () => _confirmSignOut(context, authService),
          ),
        ],
      ),
      body: uid == null
          ? const Center(child: Text('ログイン情報が取得できませんでした'))
          : StreamBuilder<AppUser?>(
              stream: userService.watchUser(uid),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final user = snapshot.data;
                if (user == null) {
                  return const Center(child: Text('プロフィールが見つかりませんでした'));
                }

                return _ProfileBody(user: user);
              },
            ),
    );
  }

  Future<void> _confirmSignOut(
    BuildContext context,
    AuthService authService,
  ) async {
    final navigator = Navigator.of(context);
    final shouldSignOut = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ログアウト'),
        content: const Text('ログアウトしますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('ログアウト'),
          ),
        ],
      ),
    );

    if (shouldSignOut != true) {
      return;
    }

    await authService.signOut();
    // signOut により AuthGate が LoginPage を表示する。プロフィールは
    // MapScreen からスタックに積まれているため、最下層まで戻して整合させる。
    navigator.popUntil((route) => route.isFirst);
  }
}

class _ProfileBody extends StatelessWidget {
  const _ProfileBody({required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    final postService = PostService();
    final hasImage = (user.profileImageUrl ?? '').isNotEmpty;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 48,
                  backgroundColor: Colors.grey.shade200,
                  backgroundImage: hasImage
                      ? CachedNetworkImageProvider(user.profileImageUrl!)
                      : null,
                  child: hasImage
                      ? null
                      : const Icon(Icons.person, size: 48, color: Colors.grey),
                ),
                const SizedBox(height: 16),
                Text(
                  user.username,
                  style: Theme.of(context).textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                if (user.bio.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(user.bio, textAlign: TextAlign.center),
                ],
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => ProfileEditPage(user: user),
                      ),
                    );
                  },
                  icon: const Icon(Icons.edit),
                  label: const Text('プロフィールを編集'),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('投稿', style: Theme.of(context).textTheme.titleMedium),
            ),
          ),
          StreamBuilder<List<Post>>(
            stream: postService.getUserPosts(user.id),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              final posts = snapshot.data ?? [];
              if (posts.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: Text('まだ投稿がありません')),
                );
              }

              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.all(8),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 5,
                  mainAxisSpacing: 4,
                  crossAxisSpacing: 4,
                ),
                itemCount: posts.length,
                itemBuilder: (context, index) {
                  final post = posts[index];
                  final thumbnailUrl = post.imageUrls.isNotEmpty
                      ? post.imageUrls.first
                      : null;
                  return GestureDetector(
                    onTap: () {
                      showDialog<void>(
                        context: context,
                        builder: (context) => PostCardView(post),
                      );
                    },
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
                            placeholder: (context, url) =>
                                Container(color: Colors.grey.shade200),
                            errorWidget: (context, url, error) => Container(
                              color: Colors.grey.shade200,
                              child: const Icon(
                                Icons.broken_image_outlined,
                                color: Colors.grey,
                              ),
                            ),
                          ),
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
