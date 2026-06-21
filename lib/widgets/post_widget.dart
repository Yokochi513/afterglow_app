import 'package:afterglow_app/models/app_user.dart';
import 'package:afterglow_app/models/post.dart';
import 'package:afterglow_app/services/auth_service.dart';
import 'package:afterglow_app/services/post_service.dart';
import 'package:afterglow_app/services/user_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class PostCardView extends StatefulWidget {
  const PostCardView(
    this.post, {
    super.key,
    this.authService,
    this.postService,
    this.userService,
  });

  final Post post;

  /// テスト時に差し替え可能。null の場合はビルド時に既定インスタンスを生成する。
  final AuthService? authService;
  final PostService? postService;
  final UserService? userService;

  @override
  State<PostCardView> createState() => _PostCardViewState();
}

class _PostCardViewState extends State<PostCardView> {
  final PageController _pageController = PageController();

  late final AuthService _authService = widget.authService ?? AuthService();
  late final PostService _postService = widget.postService ?? PostService();
  late final UserService _userService = widget.userService ?? UserService();

  bool _isDeleting = false;
  bool _isEditing = false;
  bool _isSaving = false;

  bool get _isOwner =>
      _authService.currentUserId != null &&
      _authService.currentUserId == widget.post.userId;

  /// 表示・編集中の画像一覧。編集で削除すると要素が減る。
  late List<String> _imageUrls = List<String>.of(widget.post.imageUrls);

  /// 編集中に削除された画像 URL。保存時に Storage から削除する。
  final List<String> _removedImageUrls = [];

  /// 編集キャンセル時に復元するためのバックアップ。
  late List<String> _backupImageUrls = List<String>.of(_imageUrls);
  String _backupCaption = '';

  late final TextEditingController _captionController = TextEditingController(
    text: widget.post.caption,
  );

  int _currentImageIndex = 0;
  final Map<int, DateTime> _loadStartTimes = {};

  void _measureImageLoad(int index, String url) {
    final start = DateTime.now();
    _loadStartTimes[index] = start;
    final stream = CachedNetworkImageProvider(
      url,
    ).resolve(const ImageConfiguration());
    stream.addListener(
      ImageStreamListener(
        (info, synchronousCall) {
          final recorded = _loadStartTimes.remove(index);
          if (recorded != null && !synchronousCall) {
            final ms = DateTime.now().difference(recorded).inMilliseconds;
            debugPrint('[ImageTimer] index=$index loaded in ${ms}ms  url=$url');
          } else if (synchronousCall) {
            _loadStartTimes.remove(index);
            debugPrint(
              '[ImageTimer] index=$index loaded synchronously (cache hit)  url=$url',
            );
          }
        },
        onError: (error, _) {
          _loadStartTimes.remove(index);
          debugPrint('[ImageTimer] index=$index error: $error  url=$url');
        },
      ),
    );
  }

  void _showPreviousImage() {
    if (_currentImageIndex > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
      );
    }
  }

  void _showNextImage() {
    if (_currentImageIndex < _imageUrls.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
      );
    }
  }

  void _enterEditMode() {
    setState(() {
      _backupImageUrls = List<String>.of(_imageUrls);
      _backupCaption = _captionController.text;
      _removedImageUrls.clear();
      _isEditing = true;
    });
  }

  void _cancelEdit() {
    setState(() {
      _imageUrls = List<String>.of(_backupImageUrls);
      _captionController.text = _backupCaption;
      _removedImageUrls.clear();
      _isEditing = false;
      if (_currentImageIndex >= _imageUrls.length) {
        _currentImageIndex = _imageUrls.length - 1;
      }
    });
    _syncPageController();
  }

  /// 現在表示中の画像を削除する。投稿には最低 1 枚の画像が必要なため、
  /// 残り 1 枚のときは削除を許可しない。
  void _deleteCurrentImage() {
    if (_imageUrls.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('写真は最低1枚必要です')),
      );
      return;
    }

    final index = _currentImageIndex;
    setState(() {
      _removedImageUrls.add(_imageUrls[index]);
      _imageUrls.removeAt(index);
      if (_currentImageIndex >= _imageUrls.length) {
        _currentImageIndex = _imageUrls.length - 1;
      }
    });
    _syncPageController();
  }

  /// 画像枚数が変化した後、PageController の現在ページを範囲内に合わせる。
  void _syncPageController() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_pageController.hasClients) {
        _pageController.jumpToPage(_currentImageIndex);
      }
    });
  }

  Future<void> _saveEdit() async {
    final messenger = ScaffoldMessenger.of(context);

    setState(() {
      _isSaving = true;
    });

    final success = await _postService.updatePost(
      widget.post,
      caption: _captionController.text,
      imageUrls: _imageUrls,
      removedImageUrls: _removedImageUrls,
    );

    if (!mounted) {
      return;
    }

    if (success) {
      setState(() {
        _isSaving = false;
        _isEditing = false;
        _removedImageUrls.clear();
      });
      messenger.showSnackBar(const SnackBar(content: Text('投稿を更新しました')));
    } else {
      setState(() {
        _isSaving = false;
      });
      messenger.showSnackBar(const SnackBar(content: Text('更新に失敗しました')));
    }
  }

  Future<void> _confirmDelete() async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('投稿を削除'),
        content: const Text('この投稿を削除しますか？この操作は取り消せません。'),
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

    setState(() {
      _isDeleting = true;
    });

    final success = await _postService.deletePost(widget.post);

    if (!mounted) {
      return;
    }

    if (success) {
      // Firestore から削除されると一覧/マップの StreamBuilder が自動更新される
      navigator.pop();
    } else {
      setState(() {
        _isDeleting = false;
      });
      messenger.showSnackBar(const SnackBar(content: Text('削除に失敗しました')));
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _captionController.dispose();
    super.dispose();
  }

  Widget _overlayButton({
    required IconData icon,
    required VoidCallback? onPressed,
    Color backgroundColor = Colors.black54,
  }) {
    return Container(
      decoration: BoxDecoration(color: backgroundColor, shape: BoxShape.circle),
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon, color: Colors.white),
        splashRadius: 20,
      ),
    );
  }

  /// 投稿者情報（プロフィール画像・ユーザー名）を表示する。
  Widget _buildAuthorHeader() {
    return StreamBuilder<AppUser?>(
      stream: _userService.watchUser(widget.post.userId),
      builder: (context, snapshot) {
        final author = snapshot.data;
        final hasImage = (author?.profileImageUrl ?? '').isNotEmpty;
        final username = (author?.username ?? '').isNotEmpty
            ? author!.username
            : '不明なユーザー';

        return Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: Colors.grey.shade200,
              backgroundImage: hasImage
                  ? CachedNetworkImageProvider(author!.profileImageUrl!)
                  : null,
              child: hasImage
                  ? null
                  : const Icon(Icons.person, size: 20, color: Colors.grey),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                username,
                style: Theme.of(context).textTheme.titleSmall,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        );
      },
    );
  }

  /// 所有者向けの操作ボタン群（編集/削除、または保存/キャンセル）。
  List<Widget> _buildOwnerActions() {
    if (_isEditing) {
      return [
        TextButton(
          onPressed: _isSaving ? null : _cancelEdit,
          child: const Text('キャンセル'),
        ),
        TextButton(
          onPressed: _isSaving ? null : _saveEdit,
          child: const Text('保存'),
        ),
      ];
    }

    return [
      IconButton(
        onPressed: _isDeleting ? null : _enterEditMode,
        icon: const Icon(Icons.edit_outlined),
        tooltip: '投稿を編集',
      ),
      IconButton(
        onPressed: _isDeleting ? null : _confirmDelete,
        icon: const Icon(Icons.delete_outline),
        color: Colors.red,
        tooltip: '投稿を削除',
      ),
    ];
  }

  Widget _busyOverlay(String label) {
    return Positioned.fill(
      child: ColoredBox(
        color: const Color(0x66000000),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 12),
                Text(label),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isBusy = _isDeleting || _isSaving;

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
            child: Stack(
              children: [
                AbsorbPointer(
                  absorbing: isBusy,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 投稿者情報 + 所有者向け操作
                        Row(
                          children: [
                            Expanded(child: _buildAuthorHeader()),
                            if (_isOwner) ..._buildOwnerActions(),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // 画像表示部分
                        Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: Colors.grey.shade400,
                              width: 2,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: AspectRatio(
                            aspectRatio: 4 / 3,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                Positioned.fill(
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: PageView.builder(
                                      controller: _pageController,
                                      itemCount: _imageUrls.length,
                                      onPageChanged: (index) {
                                        setState(() {
                                          _currentImageIndex = index;
                                        });
                                      },
                                      itemBuilder: (context, index) {
                                        _measureImageLoad(
                                          index,
                                          _imageUrls[index],
                                        );
                                        // 表示サイズに合わせてデコードし、メモリ使用量と
                                        // デコード時間を抑える
                                        final cacheWidth =
                                            (MediaQuery.of(context).size.width *
                                                    MediaQuery.of(
                                                      context,
                                                    ).devicePixelRatio)
                                                .round();
                                        return CachedNetworkImage(
                                          imageUrl: _imageUrls[index],
                                          width: double.infinity,
                                          height: double.infinity,
                                          fit: BoxFit.cover,
                                          memCacheWidth: cacheWidth,
                                          fadeInDuration: const Duration(
                                            milliseconds: 150,
                                          ),
                                          placeholder: (context, url) =>
                                              Container(
                                                color: Colors.grey.shade200,
                                                child: const Center(
                                                  child:
                                                      CircularProgressIndicator(),
                                                ),
                                              ),
                                          errorWidget: (context, url, error) {
                                            debugPrint(error.toString());
                                            return Container(
                                              color: Colors.grey.shade200,
                                              child: const Center(
                                                child: Icon(
                                                  Icons.broken_image_outlined,
                                                  color: Colors.grey,
                                                  size: 40,
                                                ),
                                              ),
                                            );
                                          },
                                        );
                                      },
                                    ),
                                  ),
                                ),
                                if (_imageUrls.length > 1) ...[
                                  Positioned(
                                    left: 8,
                                    child: _overlayButton(
                                      icon: Icons.chevron_left,
                                      onPressed: _currentImageIndex > 0
                                          ? _showPreviousImage
                                          : null,
                                    ),
                                  ),
                                  Positioned(
                                    right: 8,
                                    child: _overlayButton(
                                      icon: Icons.chevron_right,
                                      onPressed:
                                          _currentImageIndex <
                                              _imageUrls.length - 1
                                          ? _showNextImage
                                          : null,
                                    ),
                                  ),
                                ],
                                // 編集中は現在の画像を削除するボタンを表示する
                                if (_isEditing)
                                  Positioned(
                                    top: 8,
                                    right: 8,
                                    child: _overlayButton(
                                      icon: Icons.delete,
                                      onPressed: _deleteCurrentImage,
                                      backgroundColor: Colors.red,
                                    ),
                                  ),
                                Positioned(
                                  bottom: 8,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.black54,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      '${_currentImageIndex + 1} / ${_imageUrls.length}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (_isEditing) ...[
                          const SizedBox(height: 8),
                          Text(
                            '写真の追加はできません。不要な写真は削除してください。',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: Colors.grey.shade600),
                          ),
                        ],
                        const SizedBox(height: 20),
                        TextField(
                          controller: _captionController,
                          readOnly: !_isEditing,
                          decoration: InputDecoration(
                            labelText: '説明文',
                            floatingLabelBehavior: FloatingLabelBehavior.always,
                            border: const OutlineInputBorder(),
                            filled: _isEditing,
                          ),
                          maxLines: null,
                          minLines: 3,
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
                if (_isDeleting) _busyOverlay('削除中...'),
                if (_isSaving) _busyOverlay('保存中...'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
