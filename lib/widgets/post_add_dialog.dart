import 'dart:math' as math;
import 'dart:typed_data';

import 'package:afterglow_app/models/post.dart';
import 'package:afterglow_app/services/auth_service.dart';
import 'package:afterglow_app/services/image_service.dart';
import 'package:afterglow_app/services/post_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';

class PostAddDialog extends StatefulWidget {
  final LatLng pos;

  /// テストからサービスを差し替えるための任意の注入口（DI 方針）。
  /// 未指定なら `.instance` ベースの既定サービスを State 側で遅延生成する。
  final PostService? postService;
  final AuthService? authService;
  final ImageService? imageService;

  /// テストから選択済み画像を注入するための任意の初期値。
  /// `ImagePicker` は注入できないため、画像選択後の状態を再現する用途で使う。
  final List<XFile>? initialImages;

  const PostAddDialog({
    super.key,
    required this.pos,
    this.postService,
    this.authService,
    this.imageService,
    this.initialImages,
  });

  @override
  State<PostAddDialog> createState() => _PostAddDialogState();
}

class _PostAddDialogState extends State<PostAddDialog>
    with WidgetsBindingObserver {
  /// 投稿画像の枚数上限（PS_01 / NFR_02）。
  static const int _maxImages = 10;

  /// 入力欄のために確保する高さ。ダイアログの利用可能な高さからこれを
  /// 差し引いた分だけを画像プレビューに割り当てる（キーボード表示時に
  /// プレビューが幅いっぱいに広がって入力欄を押し出さないようにする）。
  static const double _fieldsReservedHeight = 280;

  /// 画像プレビューの最小高さ。
  static const double _previewMinHeight = 96;

  /// フォーカスからスクロール補正までの待ち時間。キーボード表示に伴う
  /// ダイアログの縮小（AnimatedPadding）が落ち着くのを待つ。
  static const Duration _focusScrollDelay = Duration(milliseconds: 350);

  final TextEditingController _captionController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _tagController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();
  final PageController _pageController = PageController();

  // 注入がなければ既定のサービスを遅延生成する（Firebase 初期化前に触らないため）
  late final PostService postService = widget.postService ?? PostService();
  late final AuthService authService = widget.authService ?? AuthService();
  late final ImageService imageService = widget.imageService ?? ImageService();

  final List<XFile> _selectedImages = [];
  final List<Uint8List> _previewImageBytes = [];
  final List<String> _tags = [];
  int _currentImageIndex = 0;
  bool _isPosting = false;

  /// 現在フォーカスされている入力欄の context。
  /// キーボード表示によるビューポート変化時のスクロール補正に使う。
  BuildContext? _focusedFieldContext;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadInitialImages();
  }

  /// [PostAddDialog.initialImages] が指定されていれば選択済み画像として読み込む。
  Future<void> _loadInitialImages() async {
    final images = widget.initialImages;
    if (images == null || images.isEmpty) {
      return;
    }
    final toAdd = images.length > _maxImages
        ? images.sublist(0, _maxImages)
        : images;
    final previewBytes = await Future.wait(
      toAdd.map((image) => image.readAsBytes()),
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _selectedImages.addAll(toAdd);
      _previewImageBytes.addAll(previewBytes);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _captionController.dispose();
    _locationController.dispose();
    _tagController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  /// ビューポート変化（キーボード表示・非表示など）時、フォーカス中の
  /// 入力欄が画面外に残らないようスクロールを補正する。
  @override
  void didChangeMetrics() {
    if (_focusedFieldContext == null) {
      return;
    }
    // Dialog の AnimatedPadding による縮小が終わるのを待ってから補正する
    Future.delayed(const Duration(milliseconds: 200), () {
      final current = _focusedFieldContext;
      if (mounted && current != null && current.mounted) {
        _ensureFieldVisible(current);
      }
    });
  }

  /// 入力欄がスクロール領域の表示範囲外にあれば範囲内へスクロールする。
  /// モバイルブラウザではキーボード表示に伴う自動スクロールが効かず、
  /// フォーカスした欄が見えないままになることがある（Issue #38 実機確認）。
  void _ensureFieldVisible(BuildContext fieldContext) {
    final renderObject = fieldContext.findRenderObject();
    final scrollable = Scrollable.maybeOf(fieldContext);
    if (renderObject is! RenderBox ||
        !renderObject.attached ||
        scrollable == null) {
      return;
    }
    final viewport = RenderAbstractViewport.maybeOf(renderObject);
    if (viewport == null) {
      return;
    }
    // 現在のスクロール位置が「上端に合わせる位置」と「下端に合わせる位置」の
    // 間にあれば全体が見えているので何もしない
    final revealTop = viewport.getOffsetToReveal(renderObject, 0.0).offset;
    final revealBottom = viewport.getOffsetToReveal(renderObject, 1.0).offset;
    final pixels = scrollable.position.pixels;
    if (pixels >= revealBottom && pixels <= revealTop) {
      return;
    }
    Scrollable.ensureVisible(
      fieldContext,
      alignment: 0.3,
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOut,
    );
  }

  /// フォーカス時にスクロール補正を仕掛けるラッパー。
  Widget _scrollIntoViewOnFocus({required Widget child}) {
    return Builder(
      builder: (fieldContext) {
        return Focus(
          skipTraversal: true,
          includeSemantics: false,
          onFocusChange: (hasFocus) {
            if (hasFocus) {
              _focusedFieldContext = fieldContext;
              Future.delayed(_focusScrollDelay, () {
                if (mounted && fieldContext.mounted) {
                  _ensureFieldVisible(fieldContext);
                }
              });
            } else if (identical(_focusedFieldContext, fieldContext)) {
              _focusedFieldContext = null;
            }
          },
          child: child,
        );
      },
    );
  }

  void _showError(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  // 複数画像選択
  Future<void> pickAndUploadImages() async {
    if (_selectedImages.length >= _maxImages) {
      _showError('画像は最大$_maxImages枚までです');
      return;
    }

    // 圧縮は投稿時に flutter_image_compress で行うため、ここでは等倍で取得する
    final List<XFile> picked = await _imagePicker.pickMultiImage();
    if (picked.isEmpty) {
      return;
    }

    // 拡張子チェック（NFR_02）
    final allowed = <XFile>[];
    var hasRejected = false;
    for (final image in picked) {
      if (imageService.isAllowedExtension(image.name)) {
        allowed.add(image);
      } else {
        hasRejected = true;
      }
    }
    if (hasRejected) {
      _showError('JPEG / PNG / BMP / HEIC 形式の画像のみ選択できます');
    }
    if (allowed.isEmpty) {
      return;
    }

    // 枚数上限チェック（PS_01）
    final remaining = _maxImages - _selectedImages.length;
    final toAdd = allowed.length > remaining
        ? allowed.sublist(0, remaining)
        : allowed;
    if (allowed.length > remaining) {
      _showError('画像は最大$_maxImages枚までです');
    }

    final previewBytes = await Future.wait(
      toAdd.map((image) => image.readAsBytes()),
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _selectedImages.addAll(toAdd);
      _previewImageBytes.addAll(previewBytes);
    });
  }

  // タグ入力（`#タグ名` を空白・カンマ区切りで複数追加）— PS_03
  void _addTagsFromInput(String raw) {
    final tokens = raw.split(RegExp(r'[\s,、]+'));
    final added = <String>[];
    for (var token in tokens) {
      token = token.trim();
      if (token.startsWith('#')) {
        token = token.substring(1).trim();
      }
      if (token.isNotEmpty &&
          !_tags.contains(token) &&
          !added.contains(token)) {
        added.add(token);
      }
    }
    if (added.isNotEmpty) {
      setState(() {
        _tags.addAll(added);
      });
    }
    _tagController.clear();
  }

  void _removeTag(String tag) {
    setState(() {
      _tags.remove(tag);
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

  /// サムネイル一覧のドラッグ&ドロップで画像を並び替える。
  /// `_selectedImages` と `_previewImageBytes` を同時に動かして同期を保ち、
  /// 表示中だった画像を並び替え後も表示し続ける。
  void reorderImage(int oldIndex, int newIndex) {
    if (oldIndex == newIndex ||
        oldIndex < 0 ||
        oldIndex >= _selectedImages.length ||
        newIndex < 0 ||
        newIndex >= _selectedImages.length) {
      return;
    }

    setState(() {
      final image = _selectedImages.removeAt(oldIndex);
      final bytes = _previewImageBytes.removeAt(oldIndex);
      _selectedImages.insert(newIndex, image);
      _previewImageBytes.insert(newIndex, bytes);

      if (_currentImageIndex == oldIndex) {
        _currentImageIndex = newIndex;
      } else if (oldIndex < _currentImageIndex &&
          newIndex >= _currentImageIndex) {
        _currentImageIndex -= 1;
      } else if (oldIndex > _currentImageIndex &&
          newIndex <= _currentImageIndex) {
        _currentImageIndex += 1;
      }
    });

    if (_pageController.hasClients) {
      _pageController.jumpToPage(_currentImageIndex);
    }
  }

  /// サムネイルをタップしたとき、その画像をプレビューに表示する。
  void _showImageAt(int index) {
    if (index < 0 || index >= _selectedImages.length) {
      return;
    }
    setState(() {
      _currentImageIndex = index;
    });
    if (_pageController.hasClients) {
      _pageController.jumpToPage(index);
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

  /// サムネイル 1 枚分の一辺の長さ。
  static const double _thumbnailSize = 64;

  /// ドラッグ開始のリスナーをプラットフォームに合わせて切り替える。
  /// タッチ端末（モバイル・モバイルブラウザ）は横スクロールと競合しないよう
  /// 長押しで開始し、マウス操作の端末は即時ドラッグで開始する。
  Widget _thumbnailDragListener({required int index, required Widget child}) {
    final platform = Theme.of(context).platform;
    final isTouchDevice =
        platform == TargetPlatform.android || platform == TargetPlatform.iOS;
    return isTouchDevice
        ? ReorderableDelayedDragStartListener(index: index, child: child)
        : ReorderableDragStartListener(index: index, child: child);
  }

  /// 選択済み画像のサムネイル一覧。ドラッグ&ドロップで並び替えられる。
  /// 並び順の 1 枚目がアルバム等のサムネイルとして使われる（Issue #40）。
  Widget _buildThumbnailStrip() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        SizedBox(
          height: _thumbnailSize + 8,
          child: ReorderableListView.builder(
            scrollDirection: Axis.horizontal,
            buildDefaultDragHandles: false,
            // ReorderableListView は移動先を「取り除く前」の位置で渡すため、
            // 後ろ方向への移動は 1 つ手前に補正して最終的な位置に直す。
            onReorder: (oldIndex, newIndex) => reorderImage(
              oldIndex,
              newIndex > oldIndex ? newIndex - 1 : newIndex,
            ),
            itemCount: _selectedImages.length,
            itemBuilder: (context, index) {
              final isCurrent = index == _currentImageIndex;
              return Padding(
                key: ObjectKey(_selectedImages[index]),
                padding: const EdgeInsets.only(right: 8),
                child: _thumbnailDragListener(
                  index: index,
                  child: GestureDetector(
                    onTap: () => _showImageAt(index),
                    child: Stack(
                      children: [
                        Container(
                          width: _thumbnailSize,
                          height: _thumbnailSize,
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: isCurrent
                                  ? Theme.of(context).colorScheme.primary
                                  : Colors.grey.shade400,
                              width: isCurrent ? 2 : 1,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(7),
                            child: Image.memory(
                              _previewImageBytes[index],
                              width: _thumbnailSize,
                              height: _thumbnailSize,
                              fit: BoxFit.cover,
                              gaplessPlayback: true,
                            ),
                          ),
                        ),
                        // 並び順の番号（1 始まり）。1 枚目がサムネイルになる
                        Positioned(
                          top: 2,
                          left: 2,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${index + 1}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'ドラッグ（タッチ操作は長押し）で並び替え。1枚目がサムネイルになります',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
        ),
      ],
    );
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
      // キーボードインセットは Dialog が内部で処理するため、ここでは重ねてパディングしない。
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 630, maxHeight: 800),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: LayoutBuilder(
            builder: (context, constraints) {
              // キーボード表示などで高さが足りないときは画像プレビューを
              // 縮めて、入力欄が見える余地を確保する
              final previewMaxHeight = math.max(
                _previewMinHeight,
                constraints.maxHeight - _fieldsReservedHeight,
              );
              return Stack(
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
                          Center(
                            child: Container(
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: Colors.grey.shade400,
                                  width: 2,
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                  maxHeight: previewMaxHeight,
                                ),
                                child: AspectRatio(
                                  aspectRatio: 4 / 3,
                                  child: _selectedImages.isEmpty
                                      ? InkWell(
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                          onTap: pickAndUploadImages,
                                          child: const Center(
                                            child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  Icons
                                                      .add_photo_alternate_outlined,
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
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                                child: PageView.builder(
                                                  controller: _pageController,
                                                  itemCount:
                                                      _selectedImages.length,
                                                  onPageChanged: (index) {
                                                    setState(() {
                                                      _currentImageIndex =
                                                          index;
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
                                                onPressed: () => removeImage(
                                                  _currentImageIndex,
                                                ),
                                              ),
                                            ),
                                            if (_selectedImages.length > 1) ...[
                                              Positioned(
                                                left: 8,
                                                child: _overlayButton(
                                                  icon: Icons.chevron_left,
                                                  onPressed:
                                                      _currentImageIndex > 0
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
                                                          _selectedImages
                                                                  .length -
                                                              1
                                                      ? _showNextImage
                                                      : null,
                                                ),
                                              ),
                                            ],
                                            Positioned(
                                              bottom: 8,
                                              child: Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 10,
                                                      vertical: 4,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: Colors.black54,
                                                  borderRadius:
                                                      BorderRadius.circular(12),
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
                            ),
                          ),
                          // 並び替え用のサムネイル一覧（Issue #40）。
                          // 1 枚では並び替えの意味がないため 2 枚以上で表示する
                          if (_selectedImages.length > 1)
                            _buildThumbnailStrip(),
                          const SizedBox(height: 8),
                          // 画像枚数の表示と追加（PS_01）
                          Row(
                            children: [
                              TextButton.icon(
                                onPressed: _selectedImages.length >= _maxImages
                                    ? null
                                    : pickAndUploadImages,
                                icon: const Icon(Icons.add_photo_alternate),
                                label: const Text('画像を追加'),
                              ),
                              const Spacer(),
                              Text('${_selectedImages.length} / $_maxImages'),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _scrollIntoViewOnFocus(
                            child: TextField(
                              controller: _captionController,
                              decoration: const InputDecoration(
                                labelText: 'キャプション',
                                border: OutlineInputBorder(),
                              ),
                              maxLines: null,
                              minLines: 3,
                            ),
                          ),
                          const SizedBox(height: 16),
                          _scrollIntoViewOnFocus(
                            child: TextField(
                              controller: _locationController,
                              decoration: const InputDecoration(
                                labelText: '場所名',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          // タグ入力（`#タグ名` で複数入力・個別削除）— PS_03
                          _scrollIntoViewOnFocus(
                            child: TextField(
                              controller: _tagController,
                              decoration: const InputDecoration(
                                labelText: 'タグ（例: #夜景 #桜）',
                                border: OutlineInputBorder(),
                                helperText: '入力してEnterで追加',
                              ),
                              textInputAction: TextInputAction.done,
                              onSubmitted: _addTagsFromInput,
                            ),
                          ),
                          if (_tags.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              children: _tags
                                  .map(
                                    (tag) => Chip(
                                      label: Text('#$tag'),
                                      onDeleted: () => _removeTag(tag),
                                    ),
                                  )
                                  .toList(),
                            ),
                          ],
                          const SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _isPosting || _selectedImages.isEmpty
                                  ? null
                                  : () async {
                                      final messenger = ScaffoldMessenger.of(
                                        context,
                                      );
                                      final navigator = Navigator.of(context);

                                      // 画像サイズ検証（1枚10MB・合計100MB）— NFR_02
                                      final sizeError = imageService
                                          .validateSizes(_previewImageBytes);
                                      if (sizeError != null) {
                                        messenger.showSnackBar(
                                          SnackBar(
                                            content: Text(sizeError),
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

                                      final locationName = _locationController
                                          .text
                                          .trim();
                                      final post = Post(
                                        id: DateTime.now()
                                            .millisecondsSinceEpoch
                                            .toString(),
                                        userId: userId,
                                        caption: _captionController.text,
                                        imageUrls: [],
                                        latitude: widget.pos.latitude,
                                        longitude: widget.pos.longitude,
                                        createdAt: DateTime.now(),
                                        locationName: locationName.isEmpty
                                            ? null
                                            : locationName,
                                        tags: List<String>.of(_tags),
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
              );
            },
          ),
        ),
      ),
    );
  }
}
