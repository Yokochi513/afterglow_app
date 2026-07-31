import 'package:afterglow_app/models/app_user.dart';
import 'package:afterglow_app/models/post.dart';
import 'package:afterglow_app/pages/image_viewer_page.dart';
import 'package:afterglow_app/pages/location_picker_page.dart';
import 'package:afterglow_app/pages/profile_page.dart';
import 'package:afterglow_app/services/auth_service.dart';
import 'package:afterglow_app/services/post_service.dart';
import 'package:afterglow_app/services/user_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

/// [PostDetailView] の表示モード。呼び出し元の文脈に応じて中身を出し分ける。
enum PostViewMode {
  /// 地図のピン押下から開く軽量表示。
  ///
  /// 「どんな写真が撮られているか」「コメントは」「いいね数は」を素早く
  /// 確認するためのもの。地図の上で開くため場所名と地図ミニプレビューは
  /// 冗長なので出さず、編集/削除も [full] 側に任せる。
  summary,

  /// フィード・プロフィールから開く詳細表示。
  ///
  /// 気に入った写真が「どこで撮られたのか」まで見られるのが利点なので、
  /// 場所名と地図ミニプレビューを出す。自投稿なら編集/削除もできる。
  full,
}

/// 投稿詳細の中身（FR_04 / §5.6）。
///
/// 画像ギャラリー・投稿者・キャプション・タグを表示し、[mode] に応じて
/// 場所名 + 地図ミニプレビューと編集/削除メニュー（PS_08）を出し分ける。
/// リアクションバー（#13）とコメントセクション（#12）は [reactionBar] /
/// [commentSection] に差し込む。
///
/// 表示器（Dialog / フルページ）を持たないため、地図のマーカータップは
/// [PostCardView] が Dialog + [PostViewMode.summary] で、フィード・プロフィール
/// からは [PostDetailPage] がフルページ + [PostViewMode.full] で、それぞれ
/// このウィジェットを包む。
/// 高さが有界なコンテナに置くこと（内部で [Stack] を使う）。
class PostDetailView extends StatefulWidget {
  /// レイアウトの切り替わりをテストから確認するためのキー。
  static const Key singleColumnKey = ValueKey('post-detail-single-column');
  static const Key twoColumnKey = ValueKey('post-detail-two-column');

  const PostDetailView(
    this.post, {
    super.key,
    this.mode = PostViewMode.full,
    this.authService,
    this.postService,
    this.userService,
    this.reactionBar,
    this.commentSection,
  });

  final Post post;

  /// 表示モード。既定は全部入りの [PostViewMode.full]。
  final PostViewMode mode;

  /// テスト時に差し替え可能。null の場合はビルド時に既定インスタンスを生成する。
  final AuthService? authService;
  final PostService? postService;
  final UserService? userService;

  /// リアクションバー（#13）の差し込み口。未指定なら表示しない。
  final Widget? reactionBar;

  /// コメントセクション（#12）の差し込み口。未指定なら表示しない。
  final Widget? commentSection;

  @override
  State<PostDetailView> createState() => _PostDetailViewState();
}

class _PostDetailViewState extends State<PostDetailView> {
  /// 地図ミニプレビューの高さとズーム。
  static const double _mapPreviewHeight = 160;
  static const double _mapPreviewZoom = 15;

  /// [PostViewMode.full] で 2 カラムに切り替える幅。これ未満は 1 カラム。
  static const double _twoColumnBreakpoint = 900;

  /// ギャラリーに重ねる丸ボタン（拡大・ページ送り・削除）の大きさ。
  static const double _overlayButtonSize = 32;
  static const double _overlayIconSize = 18;

  /// 2 カラム時の左右の幅の比と間隔。写真を主役にするため左を広く取る。
  static const int _galleryColumnFlex = 3;
  static const int _infoColumnFlex = 2;
  static const double _columnGap = 24;

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

  /// 編集/削除メニューを出すか。自投稿でも [PostViewMode.summary] では出さず、
  /// 編集導線は詳細ページ側に一本化する。
  bool get _canEdit => _isOwner && widget.mode == PostViewMode.full;

  /// 表示・編集中の画像一覧。編集で削除すると要素が減る。
  late List<String> _imageUrls = List<String>.of(widget.post.imageUrls);

  /// 編集中に削除された画像 URL。保存時に Storage から削除する。
  final List<String> _removedImageUrls = [];

  /// 編集キャンセル時に復元するためのバックアップ。
  late List<String> _backupImageUrls = List<String>.of(_imageUrls);
  String _backupCaption = '';

  /// 表示・編集中の投稿位置。位置の選び直し（Issue #37）で置き換わる。
  /// 保存後も `widget.post` は古い位置のままなので、こちらを表示に使い続ける。
  late LatLng _position = LatLng(widget.post.latitude, widget.post.longitude);

  /// 編集キャンセル時に復元するための位置バックアップ。
  late LatLng _backupPosition = _position;

  /// 編集中に位置が変更されたか。保存時に緯度経度を送るかの判定に使う。
  bool _positionChanged = false;

  late final TextEditingController _captionController = TextEditingController(
    text: widget.post.caption,
  );

  int _currentImageIndex = 0;

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
      _backupPosition = _position;
      _positionChanged = false;
      _removedImageUrls.clear();
      _isEditing = true;
    });
  }

  void _cancelEdit() {
    setState(() {
      _imageUrls = List<String>.of(_backupImageUrls);
      _captionController.text = _backupCaption;
      _position = _backupPosition;
      _positionChanged = false;
      _removedImageUrls.clear();
      _isEditing = false;
      if (_currentImageIndex >= _imageUrls.length) {
        _currentImageIndex = _imageUrls.length - 1;
      }
    });
    _syncPageController();
  }

  /// 位置選択ページを開き、選び直した位置をプレビューへ反映する（Issue #37）。
  /// キャンセル（null で戻る）のときは何もしない。
  Future<void> _changeLocation() async {
    final selected = await Navigator.of(context).push<LatLng>(
      MaterialPageRoute<LatLng>(
        builder: (_) => LocationPickerPage(initialPosition: _position),
      ),
    );
    if (selected == null || !mounted) return;
    setState(() {
      _position = selected;
      _positionChanged = true;
    });
  }

  /// 現在表示中の画像を削除する。投稿には最低 1 枚の画像が必要なため、
  /// 残り 1 枚のときは削除を許可しない。
  void _deleteCurrentImage() {
    if (_imageUrls.length <= 1) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('写真は最低1枚必要です')));
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
      // 位置は選び直したときだけ送る。null なら既存の位置を維持する。
      latitude: _positionChanged ? _position.latitude : null,
      longitude: _positionChanged ? _position.longitude : null,
    );

    if (!mounted) {
      return;
    }

    if (success) {
      setState(() {
        _isSaving = false;
        _isEditing = false;
        _removedImageUrls.clear();
        // _position は保存済みの新しい位置としてプレビュー表示に使い続ける。
        _positionChanged = false;
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
      // Firestore から削除されると一覧/マップの StreamBuilder が自動更新される。
      // pop は Dialog なら閉じ、フルページなら前の画面へ戻る。
      navigator.pop();
    } else {
      setState(() {
        _isDeleting = false;
      });
      messenger.showSnackBar(const SnackBar(content: Text('削除に失敗しました')));
    }
  }

  void _openAuthorProfile() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ProfilePage(userId: widget.post.userId),
      ),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    _captionController.dispose();
    super.dispose();
  }

  /// 写真の上に重ねる丸ボタン。スマホ幅（400px 前後）では既定サイズだと
  /// 写真を覆って邪魔になるので、小さめに詰める。
  Widget _overlayButton({
    required IconData icon,
    required VoidCallback? onPressed,
    Color backgroundColor = Colors.black54,
    String? tooltip,
  }) {
    // IconButton は既定のタップ領域（48px）に引き伸ばされて丸が大きくなるため、
    // 大きさを指定できる Material + InkWell で組む。
    final button = Material(
      color: backgroundColor,
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
    );

    return tooltip == null ? button : Tooltip(message: tooltip, child: button);
  }

  /// 投稿者情報（プロフィール画像・ユーザー名）。タップで ProfilePage へ遷移する。
  Widget _buildAuthorHeader() {
    return StreamBuilder<AppUser?>(
      stream: _userService.watchUser(widget.post.userId),
      builder: (context, snapshot) {
        final author = snapshot.data;
        final hasImage = (author?.profileImageUrl ?? '').isNotEmpty;
        final username = (author?.username ?? '').isNotEmpty
            ? author!.username
            : '不明なユーザー';

        return InkWell(
          onTap: _openAuthorProfile,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
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
            ),
          ),
        );
      },
    );
  }

  /// 所有者向けの操作メニュー（編集/削除、または保存/キャンセル）。
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

  /// 全画面ビューアを開く（Issue #45）。表示中の画像から始める。
  void _openImageViewer() {
    if (_imageUrls.isEmpty) return;
    ImageViewerPage.open(
      context,
      imageUrls: List<String>.of(_imageUrls),
      initialIndex: _currentImageIndex,
    );
  }

  /// 画像ギャラリー（PageView）。編集中は現在の画像を削除できる。
  ///
  /// 写真は縦横比がまちまちなので [BoxFit.contain] で全体を見せる
  /// （Issue #45: 一部しか見えない）。余白は塗らずに透過させ、Dialog や
  /// ページの背景と同化させる。タップすると全画面ビューアで拡大できる。
  ///
  /// [PostViewMode.summary] は Dialog 内のカードとして枠線を付けるが、
  /// [PostViewMode.full] は写真自体が主役なので枠線を外す。
  Widget _buildGallery() {
    final isSummary = widget.mode == PostViewMode.summary;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        border: isSummary
            ? Border.all(color: Colors.grey.shade400, width: 2)
            : null,
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
                    // 表示サイズに合わせてデコードし、メモリ使用量と
                    // デコード時間を抑える
                    final cacheWidth =
                        (MediaQuery.of(context).size.width *
                                MediaQuery.of(context).devicePixelRatio)
                            .round();
                    // タップで全画面ビューアへ。ページ送りのスワイプは
                    // GestureDetector の onTap と競合しない。
                    // 余白（contain の上下左右）も背景を塗らないので、
                    // 呼び出し元の背景がそのまま透けて見える。
                    return GestureDetector(
                      onTap: _openImageViewer,
                      child: CachedNetworkImage(
                        imageUrl: _imageUrls[index],
                        width: double.infinity,
                        height: double.infinity,
                        fit: BoxFit.contain,
                        memCacheWidth: cacheWidth,
                        fadeInDuration: const Duration(milliseconds: 150),
                        placeholder: (context, url) =>
                            const Center(child: CircularProgressIndicator()),
                        errorWidget: (context, url, error) => const Center(
                          child: Icon(
                            Icons.broken_image_outlined,
                            color: Colors.grey,
                            size: 40,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            // 拡大できることが分かるようにヒントを兼ねたボタンを置く
            Positioned(
              top: 6,
              left: 6,
              child: _overlayButton(
                icon: Icons.zoom_out_map,
                onPressed: _openImageViewer,
                tooltip: '写真を拡大',
              ),
            ),
            if (_imageUrls.length > 1) ...[
              Positioned(
                left: 6,
                child: _overlayButton(
                  icon: Icons.chevron_left,
                  onPressed: _currentImageIndex > 0 ? _showPreviousImage : null,
                ),
              ),
              Positioned(
                right: 6,
                child: _overlayButton(
                  icon: Icons.chevron_right,
                  onPressed: _currentImageIndex < _imageUrls.length - 1
                      ? _showNextImage
                      : null,
                ),
              ),
            ],
            // 編集中は現在の画像を削除するボタンを表示する
            if (_isEditing)
              Positioned(
                top: 6,
                right: 6,
                child: _overlayButton(
                  icon: Icons.delete,
                  onPressed: _deleteCurrentImage,
                  backgroundColor: Colors.red,
                ),
              ),
            Positioned(
              bottom: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${_currentImageIndex + 1} / ${_imageUrls.length}',
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 場所名と地図ミニプレビュー。地図は閲覧専用（操作不可）。
  /// 編集中は「位置を変更」ボタンを出し、位置の選び直し（Issue #37）へ進める。
  Widget _buildLocation() {
    final locationName = widget.post.locationName ?? '';
    final point = _position;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (locationName.isNotEmpty) ...[
          Row(
            children: [
              const Icon(Icons.place_outlined, size: 18),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  locationName,
                  style: Theme.of(context).textTheme.titleSmall,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            height: _mapPreviewHeight,
            width: double.infinity,
            child: FlutterMap(
              // FlutterMap は initialCenter の変更では再センタリングされない
              // ため、位置が変わったら座標由来のキーで再構築する。
              key: ValueKey('${point.latitude},${point.longitude}'),
              options: MapOptions(
                initialCenter: point,
                initialZoom: _mapPreviewZoom,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.none,
                ),
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.afterglow_app.app',
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: point,
                      width: 40,
                      height: 40,
                      child: const Icon(
                        Icons.location_on,
                        color: Colors.red,
                        size: 36,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        // 編集中だけ位置の選び直し導線を出す
        if (_isEditing) ...[
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _isSaving ? null : _changeLocation,
            icon: const Icon(Icons.edit_location_alt),
            label: const Text('位置を変更'),
          ),
        ],
      ],
    );
  }

  /// タグ一覧（ChipRow / PS_03）。
  Widget _buildTags() {
    return Wrap(
      spacing: 8,
      runSpacing: -4,
      children: widget.post.tags
          .map((tag) => Chip(label: Text('#$tag')))
          .toList(growable: false),
    );
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

  /// 投稿者情報 + 所有者向け操作。
  Widget _buildAuthorRow() {
    return Row(
      children: [
        Expanded(child: _buildAuthorHeader()),
        if (_canEdit) ..._buildOwnerActions(),
      ],
    );
  }

  /// 編集中だけ出す注意書き。写真の追加は投稿時のみ。
  Widget _buildEditHint() {
    return Text(
      '写真の追加はできません。不要な写真は削除してください。',
      style: Theme.of(
        context,
      ).textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
    );
  }

  Widget _buildCaptionField() {
    return TextField(
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
    );
  }

  /// 1 カラム（Dialog のサマリー・モバイルの詳細ページ）。
  Widget _buildSingleColumn() {
    return Column(
      key: PostDetailView.singleColumnKey,
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildAuthorRow(),
        const SizedBox(height: 12),
        _buildGallery(),
        if (_isEditing) ...[const SizedBox(height: 8), _buildEditHint()],
        if (widget.reactionBar != null) ...[
          const SizedBox(height: 8),
          widget.reactionBar!,
        ],
        const SizedBox(height: 20),
        _buildCaptionField(),
        if (widget.post.tags.isNotEmpty) ...[
          const SizedBox(height: 16),
          _buildTags(),
        ],
        if (widget.mode == PostViewMode.full) ...[
          const SizedBox(height: 20),
          _buildLocation(),
        ],
        if (widget.commentSection != null) ...[
          const SizedBox(height: 24),
          widget.commentSection!,
        ],
      ],
    );
  }

  /// 2 カラム（ワイド画面の詳細ページ）。左に写真を大きく、右に情報を縦に積む。
  /// ページ全体で 1 つのスクロールを共有する。
  Widget _buildTwoColumn() {
    return Row(
      key: PostDetailView.twoColumnKey,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: _galleryColumnFlex,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildGallery(),
              if (_isEditing) ...[const SizedBox(height: 8), _buildEditHint()],
            ],
          ),
        ),
        const SizedBox(width: _columnGap),
        Expanded(
          flex: _infoColumnFlex,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildAuthorRow(),
              const SizedBox(height: 12),
              _buildCaptionField(),
              if (widget.post.tags.isNotEmpty) ...[
                const SizedBox(height: 16),
                _buildTags(),
              ],
              if (widget.reactionBar != null) ...[
                const SizedBox(height: 8),
                widget.reactionBar!,
              ],
              const SizedBox(height: 20),
              _buildLocation(),
              if (widget.commentSection != null) ...[
                const SizedBox(height: 24),
                widget.commentSection!,
              ],
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isBusy = _isDeleting || _isSaving;

    return Stack(
      children: [
        AbsorbPointer(
          absorbing: isBusy,
          child: LayoutBuilder(
            builder: (context, constraints) {
              // 2 カラムは写真を大きく見せられる幅があるときの詳細ページだけ。
              // Dialog のサマリーは常に 1 カラム。
              final isTwoColumn =
                  widget.mode == PostViewMode.full &&
                  constraints.maxWidth >= _twoColumnBreakpoint;

              return SingleChildScrollView(
                child: isTwoColumn ? _buildTwoColumn() : _buildSingleColumn(),
              );
            },
          ),
        ),
        if (_isDeleting) _busyOverlay('削除中...'),
        if (_isSaving) _busyOverlay('保存中...'),
      ],
    );
  }
}
