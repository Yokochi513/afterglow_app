import 'dart:async';
import 'dart:math' as math;

import 'package:afterglow_app/data/models/contest.dart';
import 'package:afterglow_app/ui/post/photo_location_suggestion.dart';
import 'package:afterglow_app/ui/post/post_add_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

/// 投稿作成ダイアログ（PS_01 / PS_03 / Issue #40 / #46）。
///
/// 状態と入力検証・送信は [PostAddViewModel] が持ち、ここでは描画と、
/// 画像選択・ページ送り・キーボード表示時のスクロール補正といった
/// UI 固有の処理だけを扱う。
class PostAddDialog extends StatefulWidget {
  final LatLng pos;

  /// テストから選択済み画像を注入するための任意の初期値。
  /// `ImagePicker` は注入できないため、画像選択後の状態を再現する用途で使う。
  final List<XFile>? initialImages;

  const PostAddDialog({super.key, required this.pos, this.initialImages});

  @override
  State<PostAddDialog> createState() => _PostAddDialogState();
}

class _PostAddDialogState extends State<PostAddDialog>
    with WidgetsBindingObserver {
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

  late final PostAddViewModel _viewModel;
  late final StreamSubscription<PostAddNotice> _noticeSubscription;

  PostAddViewModel get vm => _viewModel;

  /// 現在フォーカスされている入力欄の context。
  /// キーボード表示によるビューポート変化時のスクロール補正に使う。
  BuildContext? _focusedFieldContext;

  @override
  void initState() {
    super.initState();
    _viewModel = PostAddViewModel(
      tappedLocation: widget.pos,
      postRepository: context.read(),
      contestRepository: context.read(),
      authRepository: context.read(),
      imageService: context.read(),
    );
    _noticeSubscription = _viewModel.notices.listen(_showNotice);
    WidgetsBinding.instance.addObserver(this);
    final initialImages = widget.initialImages;
    if (initialImages != null) {
      _viewModel.loadInitialImages(initialImages);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _noticeSubscription.cancel();
    _viewModel.dispose();
    _captionController.dispose();
    _locationController.dispose();
    _tagController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _showNotice(PostAddNotice notice) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(notice.message),
        backgroundColor: notice.isError ? Colors.red : null,
      ),
    );
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

  // 複数画像選択。圧縮は投稿時に flutter_image_compress で行うため、
  // ここでは等倍で取得する
  Future<void> _pickImages() async {
    if (!vm.checkCanPickImages()) return;
    final picked = await _imagePicker.pickMultiImage();
    if (!mounted) return;
    await vm.addImages(picked);
  }

  /// プレビューの表示位置を ViewModel の現在位置に合わせる。
  void _syncPage() {
    if (vm.images.isNotEmpty && _pageController.hasClients) {
      _pageController.jumpToPage(vm.currentImageIndex);
    }
  }

  void _removeImage(int index) {
    vm.removeImage(index);
    _syncPage();
  }

  void _reorderImage(int oldIndex, int newIndex) {
    vm.reorderImage(oldIndex, newIndex);
    _syncPage();
  }

  /// サムネイルをタップしたとき、その画像をプレビューに表示する。
  void _showImageAt(int index) {
    vm.showImageAt(index);
    _syncPage();
  }

  void _showPreviousImage() {
    if (vm.currentImageIndex > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
      );
    }
  }

  void _showNextImage() {
    if (vm.currentImageIndex < vm.images.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
      );
    }
  }

  void _addTags(String raw) {
    vm.addTagsFromInput(raw);
    _tagController.clear();
  }

  Future<void> _submit() async {
    final navigator = Navigator.of(context);
    final posted = await vm.submit(
      caption: _captionController.text,
      locationName: _locationController.text,
    );
    if (posted && mounted) navigator.pop();
  }

  /// 撮影場所の提案・採用状態を示すバナー（Issue #46）。
  /// 提案も採用もしていないときは何も表示しない。
  Widget _buildPhotoLocationBanner() {
    final result = vm.photoLocationResult;
    if (result is! PhotoLocationSuggestion && result is! PhotoLocationAdopted) {
      return const SizedBox.shrink();
    }
    final suggestion = result is PhotoLocationSuggestion ? result : null;
    final message = suggestion == null
        ? '撮影場所に投稿します'
        : suggestion.isReproposal
        ? '撮影場所が変わりました（${suggestion.photoNumber}枚目の写真）'
        : '${suggestion.photoNumber}枚目の写真の撮影場所が見つかりました'
              '（タップ地点から${PhotoLocationSuggestions.formatDistance(suggestion.distanceMeters)}）';
    return Container(
      key: const Key('photoLocationBanner'),
      width: double.infinity,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 絵文字は同梱フォントに含まれず Web で文字欠けするためアイコンで示す
          Row(
            children: [
              const Icon(Icons.place, size: 16),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  message,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ),
          Wrap(
            children: [
              if (suggestion != null) ...[
                TextButton(
                  key: const Key('usePhotoLocation'),
                  onPressed: () => vm.usePhotoLocation(suggestion.location),
                  child: const Text('撮影場所を使う'),
                ),
                TextButton(
                  key: const Key('ignorePhotoLocation'),
                  onPressed: () => vm.ignorePhotoLocation(suggestion.location),
                  child: const Text('無視'),
                ),
              ],
              if (vm.adoptedLocation != null)
                TextButton(
                  key: const Key('restoreTappedLocation'),
                  onPressed: vm.restoreTappedLocation,
                  child: const Text('元に戻す'),
                ),
            ],
          ),
        ],
      ),
    );
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
    // サムネイルは表示サイズ分だけデコードすれば十分なため、cacheWidth/
    // cacheHeight で物理ピクセルサイズに縮小デコードさせる。指定しないと
    // 元画像の解像度（iPhoneなら4000px級）のままデコードされ、選択枚数分の
    // ビットマップがメモリに乗ってクラッシュする（Issue #71、docs/adr/0001）。
    final devicePixelRatio = MediaQuery.of(context).devicePixelRatio;
    final thumbnailCacheSize = (_thumbnailSize * devicePixelRatio).round();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        SizedBox(
          height: _thumbnailSize + 8,
          child: ReorderableListView.builder(
            scrollDirection: Axis.horizontal,
            buildDefaultDragHandles: false,
            onReorderItem: _reorderImage,
            itemCount: vm.images.length,
            itemBuilder: (context, index) {
              final isCurrent = index == vm.currentImageIndex;
              return Padding(
                key: ObjectKey(vm.images[index]),
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
                              vm.previewBytes[index],
                              width: _thumbnailSize,
                              height: _thumbnailSize,
                              cacheWidth: thumbnailCacheSize,
                              cacheHeight: thumbnailCacheSize,
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

  Widget _buildContestSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('コンテストに応募する'),
          value: vm.participateInContest,
          onChanged: vm.isPosting ? null : vm.setParticipateInContest,
        ),
        if (vm.participateInContest) _buildContestList(),
      ],
    );
  }

  Widget _buildContestList() {
    return StreamBuilder<List<Contest>>(
      stream: vm.entryOpenContests,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          vm.syncSelectedContest(null);
          return const Text('コンテスト一覧を取得できませんでした');
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LinearProgressIndicator();
        }
        final contests = snapshot.data ?? const <Contest>[];
        final selected = vm.syncSelectedContest(contests);
        if (contests.isEmpty) {
          return const Text('募集中のコンテストがありません');
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownButtonFormField<Contest>(
              key: ValueKey(selected),
              initialValue: selected,
              decoration: const InputDecoration(
                labelText: '応募するコンテスト',
                border: OutlineInputBorder(),
              ),
              items: <DropdownMenuItem<Contest>>[
                ...contests.map(
                  (contest) => DropdownMenuItem<Contest>(
                    value: contest,
                    child: Text(contest.title, overflow: TextOverflow.ellipsis),
                  ),
                ),
              ],
              onChanged: vm.isPosting ? null : vm.selectContest,
            ),
            if (selected != null)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text('コンテスト終了後に投稿者名が公開されます'),
              ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _viewModel,
      builder: (context, _) => _buildDialog(context),
    );
  }

  Widget _buildDialog(BuildContext context) {
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
                    absorbing: vm.isPosting,
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
                                  child: vm.images.isEmpty
                                      ? InkWell(
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                          onTap: _pickImages,
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
                                                  itemCount: vm.images.length,
                                                  onPageChanged: vm.showImageAt,
                                                  itemBuilder: (context, index) {
                                                    return Image.memory(
                                                      vm.previewBytes[index],
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
                                                onPressed: () => _removeImage(
                                                  vm.currentImageIndex,
                                                ),
                                              ),
                                            ),
                                            if (vm.images.length > 1) ...[
                                              Positioned(
                                                left: 8,
                                                child: _overlayButton(
                                                  icon: Icons.chevron_left,
                                                  onPressed:
                                                      vm.currentImageIndex > 0
                                                      ? _showPreviousImage
                                                      : null,
                                                ),
                                              ),
                                              Positioned(
                                                right: 8,
                                                child: _overlayButton(
                                                  icon: Icons.chevron_right,
                                                  onPressed:
                                                      vm.currentImageIndex <
                                                          vm.images.length - 1
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
                                                  '${vm.currentImageIndex + 1} / ${vm.images.length}',
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
                          if (vm.images.length > 1) _buildThumbnailStrip(),
                          _buildPhotoLocationBanner(),
                          const SizedBox(height: 8),
                          // 画像枚数の表示と追加（PS_01）
                          Row(
                            children: [
                              TextButton.icon(
                                onPressed: vm.images.length >= vm.maxImages
                                    ? null
                                    : _pickImages,
                                icon: const Icon(Icons.add_photo_alternate),
                                label: const Text('画像を追加'),
                              ),
                              const Spacer(),
                              Text('${vm.images.length} / ${vm.maxImages}'),
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
                              onSubmitted: _addTags,
                            ),
                          ),
                          if (vm.tags.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              children: vm.tags
                                  .map(
                                    (tag) => Chip(
                                      label: Text('#$tag'),
                                      onDeleted: () => vm.removeTag(tag),
                                    ),
                                  )
                                  .toList(),
                            ),
                          ],
                          const SizedBox(height: 16),
                          _buildContestSelector(),
                          const SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: vm.canSubmit ? _submit : null,
                              child: vm.isPosting
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
                  if (vm.isPosting)
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
