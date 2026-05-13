import 'package:afterglow_app/models/post.dart';
import 'package:flutter/material.dart';

class PostCardView extends StatefulWidget {
  const PostCardView(this.post, {super.key});

  final Post post;

  @override
  State<PostCardView> createState() => _PostCardViewState();
}

class _PostCardViewState extends State<PostCardView> {
  final PageController _pageController = PageController();

  late final List<String> _imageUrls = widget.post.imageUrls;
  late final TextEditingController _captionController = TextEditingController(
    text: widget.post.caption,
  );

  int _currentImageIndex = 0;
  final Map<int, DateTime> _loadStartTimes = {};

  void _measureImageLoad(int index, String url) {
    final start = DateTime.now();
    _loadStartTimes[index] = start;
    final stream = NetworkImage(url).resolve(const ImageConfiguration());
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
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),
                  // 画像表示部分
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade400, width: 2),
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
                                  _measureImageLoad(index, _imageUrls[index]);
                                  return Image.network(
                                    _imageUrls[index],
                                    width: double.infinity,
                                    height: double.infinity,
                                    fit: BoxFit.cover,
                                    loadingBuilder:
                                        (context, child, loadingProgress) {
                                          if (loadingProgress == null) {
                                            return child;
                                          }

                                          return Container(
                                            color: Colors.grey.shade200,
                                            child: const Center(
                                              child:
                                                  CircularProgressIndicator(),
                                            ),
                                          );
                                        },
                                    errorBuilder: (context, error, stackTrace) {
                                      debugPrint(_imageUrls[index]);
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
                                    _currentImageIndex < _imageUrls.length - 1
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
                                style: const TextStyle(color: Colors.white),
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
        ),
      ),
    );
  }
}
