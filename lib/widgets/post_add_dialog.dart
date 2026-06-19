import 'dart:typed_data';

import 'package:afterglow_app/models/post.dart';
import 'package:afterglow_app/services/auth_service.dart';
import 'package:afterglow_app/services/post_service.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';

class PostAddDialog extends StatefulWidget {
  final LatLng pos;

  const PostAddDialog({super.key, required this.pos});

  @override
  State<PostAddDialog> createState() => _PostAddDialogState();
}

class _PostAddDialogState extends State<PostAddDialog> {
  final TextEditingController _captionController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();
  final PageController _pageController = PageController();

  final PostService postService = PostService();
  final AuthService authService = AuthService();

  final List<XFile> _selectedImages = [];
  final List<Uint8List> _previewImageBytes = [];
  int _currentImageIndex = 0;
  bool _isPosting = false;

  @override
  void dispose() {
    _captionController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  // 複数画像選択
  Future<void> pickAndUploadImages() async {
    // ピック時にリサイズ・再圧縮し、アップロード/ダウンロードを軽量化する
    final List<XFile> picked = await _imagePicker.pickMultiImage(
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 85,
    );
    if (picked.isEmpty) {
      return;
    }

    final previewBytes = await Future.wait(
      picked.map((image) => image.readAsBytes()),
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _selectedImages.addAll(picked);
      _previewImageBytes.addAll(previewBytes);
    });
  }

  // 個別画像削除
  void removeImage(int index) {
    if (index < 0 || index >= _selectedImages.length) return;

    setState(() {
      _selectedImages.removeAt(index);
      _previewImageBytes.removeAt(index);
      if (_selectedImages.isEmpty) {
        _currentImageIndex = 0;
      } else if (_currentImageIndex >= _selectedImages.length) {
        _currentImageIndex = _selectedImages.length - 1;
      }
    });

    if (_selectedImages.isNotEmpty && _pageController.hasClients) {
      _pageController.jumpToPage(_currentImageIndex);
    }
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
    if (_currentImageIndex < _selectedImages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
      );
    }
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
                  absorbing: _isPosting,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '投稿',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 12),
                        // 画像プレビューと選択
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
                            child: _selectedImages.isEmpty
                                ? InkWell(
                                    borderRadius: BorderRadius.circular(10),
                                    onTap: pickAndUploadImages,
                                    child: const Center(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.add_photo_alternate_outlined,
                                            size: 40,
                                          ),
                                          SizedBox(height: 8),
                                          Text('タップして画像を選択'),
                                        ],
                                      ),
                                    ),
                                  )
                                : Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      Positioned.fill(
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                          child: PageView.builder(
                                            controller: _pageController,
                                            itemCount: _selectedImages.length,
                                            onPageChanged: (index) {
                                              setState(() {
                                                _currentImageIndex = index;
                                              });
                                            },
                                            itemBuilder: (context, index) {
                                              return Image.memory(
                                                _previewImageBytes[index],
                                                width: double.infinity,
                                                height: double.infinity,
                                                fit: BoxFit.cover,
                                                gaplessPlayback: true,
                                              );
                                            },
                                          ),
                                        ),
                                      ),
                                      Positioned(
                                        top: 8,
                                        right: 8,
                                        child: _overlayButton(
                                          icon: Icons.close,
                                          onPressed: () =>
                                              removeImage(_currentImageIndex),
                                        ),
                                      ),
                                      if (_selectedImages.length > 1) ...[
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
                                                    _selectedImages.length - 1
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
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          child: Text(
                                            '${_currentImageIndex + 1} / ${_selectedImages.length}',
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
                          decoration: const InputDecoration(
                            labelText: 'キャプション',
                            border: OutlineInputBorder(),
                          ),
                          maxLines: null,
                          minLines: 3,
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _isPosting
                                ? null
                                : () async {
                                    final messenger = ScaffoldMessenger.of(
                                      context,
                                    );
                                    final navigator = Navigator.of(context);

                                    if (_selectedImages.isEmpty) {
                                      messenger.showSnackBar(
                                        const SnackBar(
                                          content: Text('画像を選択してください'),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                      return;
                                    }

                                    final userId = authService.currentUserId;
                                    if (userId == null) {
                                      messenger.showSnackBar(
                                        const SnackBar(
                                          content: Text('ログインが必要です'),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                      return;
                                    }

                                    setState(() {
                                      _isPosting = true;
                                    });

                                    final post = Post(
                                      id: DateTime.now().millisecondsSinceEpoch
                                          .toString(),
                                      userId: userId,
                                      caption: _captionController.text,
                                      imageUrls: [],
                                      latitude: widget.pos.latitude,
                                      longitude: widget.pos.longitude,
                                      createdAt: DateTime.now(),
                                    );

                                    final success = await postService
                                        .createPost(post, _selectedImages);

                                    if (!mounted) {
                                      return;
                                    }

                                    if (success) {
                                      navigator.pop();
                                    } else {
                                      setState(() {
                                        _isPosting = false;
                                      });
                                      messenger.showSnackBar(
                                        const SnackBar(
                                          content: Text('投稿に失敗しました'),
                                        ),
                                      );
                                    }
                                  },
                            child: _isPosting
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text('投稿する'),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                    ),
                  ),
                ),
                if (_isPosting)
                  Positioned.fill(
                    child: ColoredBox(
                      color: Color(0x66000000),
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
                              Text('投稿中...'),
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
