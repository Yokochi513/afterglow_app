import 'dart:typed_data';

import 'package:afterglow_app/models/post.dart';
import 'package:afterglow_app/services/auth_service.dart';
import 'package:afterglow_app/services/image_service.dart';
import 'package:afterglow_app/services/location_service.dart';
import 'package:afterglow_app/services/post_service.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';

class PostAddDialog extends StatefulWidget {
  final LatLng pos;

  const PostAddDialog({
    super.key,
    required this.pos,
    LocationService? locationService,
  }) : _locationService = locationService;

  /// テストからモックを注入するための位置情報サービス（省略時は既定実装）。
  final LocationService? _locationService;

  @override
  State<PostAddDialog> createState() => _PostAddDialogState();
}

class _PostAddDialogState extends State<PostAddDialog> {
  /// 投稿画像の枚数上限（PS_01 / NFR_02）。
  static const int _maxImages = 10;

  final TextEditingController _captionController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _tagController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();
  final PageController _pageController = PageController();

  final PostService postService = PostService();
  final AuthService authService = AuthService();
  final ImageService imageService = ImageService();
  late final LocationService locationService =
      widget._locationService ?? LocationService();

  final List<XFile> _selectedImages = [];
  final List<Uint8List> _previewImageBytes = [];
  final List<String> _tags = [];
  int _currentImageIndex = 0;
  bool _isPosting = false;

  /// 現在地から場所名フィールドへ座標を補助入力している最中は true。
  bool _isFetchingLocation = false;

  @override
  void dispose() {
    _captionController.dispose();
    _locationController.dispose();
    _tagController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _showError(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  /// 現在地を取得し、場所名フィールドへ座標（緯度・経度）を補助入力する。
  /// 失敗してもクラッシュせず、理由を SnackBar で案内する（任意機能・PS_04）。
  Future<void> _fillLocationFromGps() async {
    if (_isFetchingLocation) return;
    setState(() => _isFetchingLocation = true);

    final result = await locationService.getCurrentLocation();

    if (!mounted) return;
    setState(() => _isFetchingLocation = false);

    if (result.isSuccess) {
      final position = result.position!;
      _locationController.text =
          '${position.latitude.toStringAsFixed(6)}, '
          '${position.longitude.toStringAsFixed(6)}';
      return;
    }

    _showError(LocationService.messageFor(result.errorType!));
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
                        TextField(
                          controller: _captionController,
                          decoration: const InputDecoration(
                            labelText: 'キャプション',
                            border: OutlineInputBorder(),
                          ),
                          maxLines: null,
                          minLines: 3,
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _locationController,
                          decoration: InputDecoration(
                            labelText: '場所名',
                            border: const OutlineInputBorder(),
                            helperText: '現在地ボタンで座標を自動入力できます',
                            suffixIcon: IconButton(
                              tooltip: '現在地の座標を入力',
                              onPressed: _isFetchingLocation
                                  ? null
                                  : _fillLocationFromGps,
                              icon: _isFetchingLocation
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.my_location),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        // タグ入力（`#タグ名` で複数入力・個別削除）— PS_03
                        TextField(
                          controller: _tagController,
                          decoration: const InputDecoration(
                            labelText: 'タグ（例: #夜景 #桜）',
                            border: OutlineInputBorder(),
                            helperText: '入力してEnterで追加',
                          ),
                          textInputAction: TextInputAction.done,
                          onSubmitted: _addTagsFromInput,
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
                                      id: DateTime.now().millisecondsSinceEpoch
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
            ),
          ),
        ),
      ),
    );
  }
}
