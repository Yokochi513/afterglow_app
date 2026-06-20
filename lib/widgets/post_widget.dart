import 'package:afterglow_app/models/post.dart';
import 'package:afterglow_app/services/auth_service.dart';
import 'package:afterglow_app/services/post_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class PostCardView extends StatefulWidget {
  const PostCardView(
    this.post, {
    super.key,
    this.authService,
    this.postService,
  });

  final Post post;

  /// テスト時に差し替え可能。null の場合はビルド時に既定インスタンスを生成する。
  final AuthService? authService;
  final PostService? postService;

  @override
  State<PostCardView> createState() => _PostCardViewState();
}

class _PostCardViewState extends State<PostCardView> {
  final PageController _pageController = PageController();

  late final AuthService _authService = widget.authService ?? AuthService();
  late final PostService _postService = widget.postService ?? PostService();

  bool _isDeleting = false;

  bool get _isOwner =>
      _authService.currentUserId != null &&
      _authService.currentUserId == widget.post.userId;

  late final List<String> _imageUrls = widget.post.imageUrls;
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
  }) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.black54,
        shape: BoxShape.circle,
      ),
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon, color: Colors.white),
        splashRadius: 20,
      ),
    );
  }

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
            child: Stack(
              children: [
                AbsorbPointer(
                  absorbing: _isDeleting,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_isOwner)
                          Align(
                            alignment: Alignment.centerRight,
                            child: IconButton(
                              onPressed: _isDeleting ? null : _confirmDelete,
                              icon: const Icon(Icons.delete_outline),
                              color: Colors.red,
                              tooltip: '投稿を削除',
                            ),
                          )
                        else
                          const SizedBox(height: 20),
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
                        const SizedBox(height: 20),
                        TextField(
                          controller: _captionController,
                          readOnly: true,
                          decoration: const InputDecoration(
                            labelText: 'キャプション',
                            border: OutlineInputBorder(),
                          ),
                          maxLines: null,
                          minLines: 3,
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
                if (_isDeleting)
                  Positioned.fill(
                    child: ColoredBox(
                      color: const Color(0x66000000),
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 20,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircularProgressIndicator(),
                              SizedBox(height: 12),
                              Text('削除中...'),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
