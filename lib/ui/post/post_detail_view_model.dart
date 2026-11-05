import 'package:afterglow_app/data/models/app_user.dart';
import 'package:afterglow_app/data/models/contest.dart';
import 'package:afterglow_app/data/models/post.dart';
import 'package:afterglow_app/data/repositories/auth_repository.dart';
import 'package:afterglow_app/data/repositories/contest_repository.dart';
import 'package:afterglow_app/data/repositories/post_repository.dart';
import 'package:afterglow_app/data/repositories/user_repository.dart';
import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

/// 投稿詳細（[PostDetailView]）の状態とロジック（FR_04 / PS_08）。
///
/// 編集・削除できるかの判定、編集中の画像一覧・並び順・位置（Issue #37 / #80）、
/// 保存・削除の送信と送信中フラグを持つ。説明文の入力値は画面側の
/// `TextEditingController` が持ち、編集の開始・取り消し・保存時に受け渡す。
class PostDetailViewModel extends ChangeNotifier {
  PostDetailViewModel({
    required this.post,
    required AuthRepository authRepository,
    required PostRepository postRepository,
    required UserRepository userRepository,
    required ContestRepository contestRepository,
  }) : _authRepository = authRepository,
       _postRepository = postRepository,
       _userRepository = userRepository,
       _contestRepository = contestRepository,
       _imageUrls = List<String>.of(post.imageUrls),
       _position = LatLng(post.latitude, post.longitude) {
    _backupImageUrls = List<String>.of(_imageUrls);
    _backupPosition = _position;
  }

  final Post post;
  final AuthRepository _authRepository;
  final PostRepository _postRepository;
  final UserRepository _userRepository;
  final ContestRepository _contestRepository;

  bool _disposed = false;

  bool _canManagePost = false;
  bool _isDeleting = false;
  bool _isEditing = false;
  bool _isSaving = false;
  int _currentImageIndex = 0;

  /// 表示・編集中の画像一覧。編集で削除すると要素が減る。
  List<String> _imageUrls;

  /// 編集中に削除された画像 URL。保存時に Storage から削除する。
  final List<String> _removedImageUrls = [];

  /// 表示・編集中の投稿位置。位置の選び直し（Issue #37）で置き換わる。
  /// 保存後も [post] は古い位置のままなので、こちらを表示に使い続ける。
  LatLng _position;

  /// 編集中に位置が変更されたか。保存時に緯度経度を送るかの判定に使う。
  bool _positionChanged = false;

  // 編集キャンセル時に復元するためのバックアップ。
  late List<String> _backupImageUrls;
  late LatLng _backupPosition;
  String _backupCaption = '';

  /// 投稿者（匿名のコンテスト投稿は購読しない）。
  late final Stream<AppUser?> author = _userRepository.watchUser(post.userId);

  /// 自投稿（またはコンテスト投稿で編集・削除してよい状態）か。
  bool get canManagePost => _canManagePost;
  bool get isDeleting => _isDeleting;
  bool get isEditing => _isEditing;
  bool get isSaving => _isSaving;
  bool get isBusy => _isDeleting || _isSaving;
  int get currentImageIndex => _currentImageIndex;
  List<String> get imageUrls => List.unmodifiable(_imageUrls);
  LatLng get position => _position;

  /// 編集/削除の権限を判定する。
  Future<void> loadManagePermission() async {
    final uid = _authRepository.currentUserId;
    if (uid == null) return;

    // 通常投稿は本体の userId で同期的に判定できる（Firestore アクセス不要）。
    // 匿名期間中のコンテスト投稿だけ、実投稿者を private/author から解決する
    // 必要があるため非同期になる（ADR 0002 §3）。
    final contestId = post.contestId;
    if (contestId == null) {
      _canManagePost = post.userId == uid;
      notifyListeners();
      return;
    }

    final authorId = await _postRepository.getAuthorId(post.id);
    final currentUser = await _userRepository.getUser(uid);
    final contest = await _contestRepository.getContest(contestId);
    if (_disposed) return;

    // コンテスト投稿の編集・削除は本人 or 管理者、かつエントリー期間中のみ
    // （ADR 0002 §8）。管理者はフェーズに関わらず削除できる規定だが、この
    // 画面は編集・削除ボタンをまとめて出すため、実務上の影響が
    // ない範囲で同じ条件にまとめている。
    final isEntryOpen = contest?.phase == ContestPhase.entry;
    _canManagePost =
        (authorId == uid || currentUser?.isAdmin == true) && isEntryOpen;
    notifyListeners();
  }

  /// ギャラリーの表示位置を更新する（スワイプ時）。
  void showImageAt(int index) {
    if (index == _currentImageIndex) return;
    _currentImageIndex = index;
    notifyListeners();
  }

  /// 編集を始める。取り消し時に戻せるよう現在の [caption] を控えておく。
  void enterEditMode({required String caption}) {
    _backupImageUrls = List<String>.of(_imageUrls);
    _backupCaption = caption;
    _backupPosition = _position;
    _positionChanged = false;
    _removedImageUrls.clear();
    _isEditing = true;
    notifyListeners();
  }

  /// 編集を取り消して編集前の状態に戻す。戻すべき説明文を返す。
  String cancelEdit() {
    _imageUrls = List<String>.of(_backupImageUrls);
    _position = _backupPosition;
    _positionChanged = false;
    _removedImageUrls.clear();
    _isEditing = false;
    if (_currentImageIndex >= _imageUrls.length) {
      _currentImageIndex = _imageUrls.length - 1;
    }
    notifyListeners();
    return _backupCaption;
  }

  /// 選び直した位置をプレビューへ反映する（Issue #37）。
  void changePosition(LatLng position) {
    _position = position;
    _positionChanged = true;
    notifyListeners();
  }

  /// 表示中の画像を削除する。投稿には最低 1 枚の画像が必要なため、
  /// 残り 1 枚のときは削除せず false を返す。
  bool deleteCurrentImage() {
    if (_imageUrls.length <= 1) return false;
    _removedImageUrls.add(_imageUrls.removeAt(_currentImageIndex));
    if (_currentImageIndex >= _imageUrls.length) {
      _currentImageIndex = _imageUrls.length - 1;
    }
    notifyListeners();
    return true;
  }

  /// 表示中の画像を [targetIndex] へ移動する（Issue #80）。先頭の画像が
  /// サムネイルになるため、並び替えでサムネイルを選び直せる。
  void moveCurrentImage(int targetIndex) {
    if (!_isEditing ||
        _isSaving ||
        targetIndex < 0 ||
        targetIndex >= _imageUrls.length ||
        targetIndex == _currentImageIndex) {
      return;
    }
    _imageUrls.insert(targetIndex, _imageUrls.removeAt(_currentImageIndex));
    _currentImageIndex = targetIndex;
    notifyListeners();
  }

  /// 編集内容を保存する。成功したら true を返す。
  Future<bool> saveEdit({required String caption}) async {
    _isSaving = true;
    notifyListeners();

    final success = await _postRepository.updatePost(
      post,
      caption: caption,
      imageUrls: List<String>.of(_imageUrls),
      removedImageUrls: List<String>.of(_removedImageUrls),
      // 位置は選び直したときだけ送る。null なら既存の位置を維持する。
      latitude: _positionChanged ? _position.latitude : null,
      longitude: _positionChanged ? _position.longitude : null,
    );
    if (_disposed) return success;

    _isSaving = false;
    if (success) {
      _isEditing = false;
      _removedImageUrls.clear();
      // _position は保存済みの新しい位置としてプレビュー表示に使い続ける。
      _positionChanged = false;
    }
    notifyListeners();
    return success;
  }

  /// 投稿を削除する。成功したら true を返す（画面は閉じる）。
  Future<bool> deletePost() async {
    _isDeleting = true;
    notifyListeners();

    final success = await _postRepository.deletePost(post);
    if (_disposed) return success;

    if (!success) {
      _isDeleting = false;
      notifyListeners();
    }
    return success;
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
