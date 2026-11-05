import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// 写真の全画面ビューア（Issue #45）。
///
/// 投稿ギャラリーのサムネイルは限られた枠に収めるため写真が小さいので、
/// 「もっと大きく見たい」に応えるために全画面で開く。写真は
/// [BoxFit.contain] で全体を表示し、ピンチ / ダブルタップで拡大できる。
/// 複数枚あるときは左右スワイプと矢印ボタンで送れる。
class ImageViewerPage extends StatefulWidget {
  /// 拡大中はページ送りを止めるため、テストから状態を確認するためのキー。
  static const Key pageViewKey = ValueKey('image-viewer-page-view');

  const ImageViewerPage({
    super.key,
    required this.imageUrls,
    this.initialIndex = 0,
  });

  /// 表示する画像 URL の一覧。表示順は呼び出し元のギャラリーと揃える。
  final List<String> imageUrls;

  /// 最初に表示する画像の位置。範囲外なら範囲内に丸める。
  final int initialIndex;

  /// ビューアを開く。呼び出し側で MaterialPageRoute を組み立てなくて済むよう
  /// ここに寄せる。
  static Future<void> open(
    BuildContext context, {
    required List<String> imageUrls,
    int initialIndex = 0,
  }) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) =>
            ImageViewerPage(imageUrls: imageUrls, initialIndex: initialIndex),
      ),
    );
  }

  @override
  State<ImageViewerPage> createState() => _ImageViewerPageState();
}

class _ImageViewerPageState extends State<ImageViewerPage> {
  /// ページ送りボタンの大きさ。全画面でも写真の邪魔にならない程度に抑える。
  static const double _overlayButtonSize = 40;
  static const double _overlayIconSize = 22;

  late int _currentIndex = widget.initialIndex.clamp(
    0,
    widget.imageUrls.isEmpty ? 0 : widget.imageUrls.length - 1,
  );

  late final PageController _pageController = PageController(
    initialPage: _currentIndex,
  );

  /// 画像ごとの拡大率。拡大中のページはスワイプでのページ送りを止め、
  /// ドラッグを写真の移動に使わせる。
  final Map<int, double> _scales = {};

  bool get _isZoomed => (_scales[_currentIndex] ?? 1) > 1.01;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _handleScaleChanged(int index, double scale) {
    final wasZoomed = _isZoomed;
    _scales[index] = scale;
    if (wasZoomed != _isZoomed) {
      setState(() {});
    }
  }

  void _showPreviousImage() {
    _pageController.previousPage(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
    );
  }

  void _showNextImage() {
    _pageController.nextPage(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
    );
  }

  /// 写真の上に重ねるページ送りボタン。写真を隠しすぎないよう控えめにする。
  Widget _overlayButton({
    required IconData icon,
    required VoidCallback? onPressed,
    required String tooltip,
  }) {
    // IconButton は既定のタップ領域（48px）に引き伸ばされて丸が大きくなるため、
    // 大きさを指定できる Material + InkWell で組む。
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.black54,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: SizedBox(
            width: _overlayButtonSize,
            height: _overlayButtonSize,
            child: Icon(
              icon,
              size: _overlayIconSize,
              color: onPressed == null ? Colors.white38 : Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final imageUrls = widget.imageUrls;
    final hasMultiple = imageUrls.length > 1;

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.black38,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          hasMultiple ? '${_currentIndex + 1} / ${imageUrls.length}' : '写真',
        ),
      ),
      body: imageUrls.isEmpty
          ? const Center(
              child: Icon(
                Icons.image_not_supported,
                color: Colors.white54,
                size: 48,
              ),
            )
          : Stack(
              alignment: Alignment.center,
              children: [
                PageView.builder(
                  key: ImageViewerPage.pageViewKey,
                  controller: _pageController,
                  // 拡大中のドラッグは写真の移動に使うためページ送りを止める。
                  physics: _isZoomed
                      ? const NeverScrollableScrollPhysics()
                      : const PageScrollPhysics(),
                  itemCount: imageUrls.length,
                  onPageChanged: (index) {
                    setState(() {
                      _currentIndex = index;
                    });
                  },
                  itemBuilder: (context, index) => _ZoomableImage(
                    imageUrl: imageUrls[index],
                    onScaleChanged: (scale) =>
                        _handleScaleChanged(index, scale),
                  ),
                ),
                if (hasMultiple) ...[
                  Positioned(
                    left: 8,
                    child: _overlayButton(
                      icon: Icons.chevron_left,
                      tooltip: '前の写真',
                      onPressed: _currentIndex > 0 ? _showPreviousImage : null,
                    ),
                  ),
                  Positioned(
                    right: 8,
                    child: _overlayButton(
                      icon: Icons.chevron_right,
                      tooltip: '次の写真',
                      onPressed: _currentIndex < imageUrls.length - 1
                          ? _showNextImage
                          : null,
                    ),
                  ),
                ],
              ],
            ),
    );
  }
}

/// ピンチとダブルタップで拡大できる 1 枚の写真。
class _ZoomableImage extends StatefulWidget {
  const _ZoomableImage({required this.imageUrl, required this.onScaleChanged});

  final String imageUrl;

  /// 拡大率が変わるたびに呼ばれる。親がページ送りの可否を決めるのに使う。
  final ValueChanged<double> onScaleChanged;

  @override
  State<_ZoomableImage> createState() => _ZoomableImageState();
}

class _ZoomableImageState extends State<_ZoomableImage>
    with SingleTickerProviderStateMixin {
  /// ダブルタップで拡大する倍率と、ピンチで許す上限。
  static const double _doubleTapScale = 2.5;
  static const double _maxScale = 5;

  final TransformationController _transformationController =
      TransformationController();

  late final AnimationController _animationController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 200),
  );

  Animation<Matrix4>? _animation;
  Offset? _doubleTapPosition;

  @override
  void initState() {
    super.initState();
    _transformationController.addListener(_notifyScale);
    _animationController.addListener(() {
      final animation = _animation;
      if (animation != null) {
        _transformationController.value = animation.value;
      }
    });
  }

  @override
  void dispose() {
    _transformationController.removeListener(_notifyScale);
    _transformationController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _notifyScale() {
    widget.onScaleChanged(_transformationController.value.getMaxScaleOnAxis());
  }

  void _handleDoubleTap() {
    final isZoomed = _transformationController.value.getMaxScaleOnAxis() > 1.01;

    final Matrix4 target;
    if (isZoomed) {
      target = Matrix4.identity();
    } else {
      // タップした点を中心に拡大する。
      final position = _doubleTapPosition ?? Offset.zero;
      target = Matrix4.identity()
        ..translateByDouble(
          -position.dx * (_doubleTapScale - 1),
          -position.dy * (_doubleTapScale - 1),
          0,
          1,
        )
        ..scaleByDouble(_doubleTapScale, _doubleTapScale, 1, 1);
    }

    _animation =
        Matrix4Tween(
          begin: _transformationController.value,
          end: target,
        ).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Curves.easeInOut,
          ),
        );
    _animationController.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onDoubleTapDown: (details) => _doubleTapPosition = details.localPosition,
      onDoubleTap: _handleDoubleTap,
      child: InteractiveViewer(
        transformationController: _transformationController,
        minScale: 1,
        maxScale: _maxScale,
        child: Center(
          child: CachedNetworkImage(
            imageUrl: widget.imageUrl,
            fit: BoxFit.contain,
            width: double.infinity,
            height: double.infinity,
            placeholder: (context, url) =>
                const Center(child: CircularProgressIndicator()),
            errorWidget: (context, url, error) => const Center(
              child: Icon(
                Icons.broken_image_outlined,
                color: Colors.white54,
                size: 48,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
