import 'dart:async';

import 'package:afterglow_app/data/models/contest.dart';
import 'package:afterglow_app/data/models/post.dart';
import 'package:afterglow_app/data/repositories/auth_repository.dart';
import 'package:afterglow_app/data/repositories/contest_repository.dart';
import 'package:afterglow_app/data/repositories/post_repository.dart';
import 'package:afterglow_app/data/services/image_service.dart';
import 'package:afterglow_app/ui/post/photo_location_suggestion.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';

/// 投稿作成画面から利用者へ伝える通知（SnackBar で表示する）。
class PostAddNotice {
  const PostAddNotice(this.message, {this.isError = true});

  final String message;

  /// エラーなら赤背景で表示する。
  final bool isError;
}

/// 投稿作成ダイアログ（[PostAddDialog]）の状態とロジック。
///
/// 選択画像・撮影場所の提案（Issue #46）・タグ・コンテスト応募・送信中フラグを
/// 保持し、入力検証と投稿の送信を行う。画面への一時的な通知は [notices] で流す。
/// `BuildContext` やウィジェットには依存しない。
class PostAddViewModel extends ChangeNotifier {
  PostAddViewModel({
    required this.tappedLocation,
    required PostRepository postRepository,
    required ContestRepository contestRepository,
    required AuthRepository authRepository,
    required ImageService imageService,
  }) : _postRepository = postRepository,
       _authRepository = authRepository,
       _imageService = imageService,
       entryOpenContests = contestRepository.getEntryOpenContests();

  /// 地図上でタップした投稿地点。
  final LatLng tappedLocation;

  final PostRepository _postRepository;
  final AuthRepository _authRepository;
  final ImageService _imageService;

  /// 応募を受け付けているコンテストの一覧。
  final Stream<List<Contest>> entryOpenContests;

  /// コンテスト未選択時の投稿画像の枚数上限（PS_01 / NFR_02）。
  static const int defaultMaxImages = 10;

  final StreamController<PostAddNotice> _notices =
      StreamController<PostAddNotice>.broadcast();
  bool _disposed = false;

  final List<XFile> _images = [];
  final List<Uint8List> _previewBytes = [];
  final List<LatLng?> _photoLocations = [];
  LatLng? _adoptedLocation;
  LatLng? _ignoredLocation;
  PhotoLocationResult _photoLocationResult = const NoPhotoLocationSuggestion();
  final List<String> _tags = [];
  int _currentImageIndex = 0;
  bool _isPosting = false;
  bool _participateInContest = false;
  Contest? _selectedContest;

  /// 利用者へ伝える通知。
  Stream<PostAddNotice> get notices => _notices.stream;

  List<XFile> get images => List.unmodifiable(_images);
  List<Uint8List> get previewBytes => List.unmodifiable(_previewBytes);
  List<String> get tags => List.unmodifiable(_tags);
  int get currentImageIndex => _currentImageIndex;
  bool get isPosting => _isPosting;
  bool get participateInContest => _participateInContest;
  Contest? get selectedContest => _selectedContest;
  PhotoLocationResult get photoLocationResult => _photoLocationResult;

  /// 撮影場所を採用している場合はその位置。
  LatLng? get adoptedLocation => _adoptedLocation;

  /// 投稿画像の枚数上限。応募先のコンテストに上限があればそれに従う。
  int get maxImages => _selectedContest?.maxImages ?? defaultMaxImages;

  bool get canAddImages => _images.length < maxImages;
  bool get canSubmit => !_isPosting && _images.isNotEmpty;

  // ---- 画像 ----

  /// 初期画像（テストや再表示用）を読み込む。上限を超える分は捨てる。
  Future<void> loadInitialImages(List<XFile> images) async {
    if (images.isEmpty) return;
    final toAdd = images.length > maxImages
        ? images.sublist(0, maxImages)
        : images;
    await _appendImages(toAdd);
  }

  /// ギャラリーで選んだ画像を検証して追加する。
  Future<void> addImages(List<XFile> picked) async {
    if (picked.isEmpty) return;

    // 拡張子チェック（NFR_02）
    final allowed = picked
        .where((image) => _imageService.isAllowedExtension(image.name))
        .toList();
    if (allowed.length != picked.length) {
      _notify('JPEG / PNG / BMP / HEIC 形式の画像のみ選択できます');
    }
    if (allowed.isEmpty) return;

    // 枚数上限チェック（PS_01）
    final remaining = maxImages - _images.length;
    final toAdd = allowed.length > remaining
        ? allowed.sublist(0, remaining)
        : allowed;
    if (allowed.length > remaining) {
      _notify('画像は最大$maxImages枚までです');
    }
    await _appendImages(toAdd);
  }

  /// 画像選択を始めてよいか。上限に達していれば通知して false を返す。
  bool checkCanPickImages() {
    if (canAddImages) return true;
    _notify('画像は最大$maxImages枚までです');
    return false;
  }

  Future<void> _appendImages(List<XFile> toAdd) async {
    final bytes = await Future.wait(toAdd.map((image) => image.readAsBytes()));
    if (_disposed) return;
    final locations = await Future.wait(
      bytes.map(_imageService.extractGpsLocation),
    );
    if (_disposed) return;
    _images.addAll(toAdd);
    _previewBytes.addAll(bytes);
    _photoLocations.addAll(locations);
    _refreshPhotoLocation();
    notifyListeners();
  }

  /// [index] の画像を外す。表示位置は範囲内に収める。
  void removeImage(int index) {
    if (index < 0 || index >= _images.length) return;
    _images.removeAt(index);
    _previewBytes.removeAt(index);
    _photoLocations.removeAt(index);
    _refreshPhotoLocation();
    if (_images.isEmpty) {
      _currentImageIndex = 0;
    } else if (_currentImageIndex >= _images.length) {
      _currentImageIndex = _images.length - 1;
    }
    notifyListeners();
  }

  /// 画像を並び替える（Issue #40）。表示中だった画像を並び替え後も表示し続ける。
  void reorderImage(int oldIndex, int newIndex) {
    if (oldIndex == newIndex ||
        oldIndex < 0 ||
        oldIndex >= _images.length ||
        newIndex < 0 ||
        newIndex >= _images.length) {
      return;
    }
    _images.insert(newIndex, _images.removeAt(oldIndex));
    _previewBytes.insert(newIndex, _previewBytes.removeAt(oldIndex));
    _photoLocations.insert(newIndex, _photoLocations.removeAt(oldIndex));
    _refreshPhotoLocation();

    if (_currentImageIndex == oldIndex) {
      _currentImageIndex = newIndex;
    } else if (oldIndex < _currentImageIndex &&
        newIndex >= _currentImageIndex) {
      _currentImageIndex -= 1;
    } else if (oldIndex > _currentImageIndex &&
        newIndex <= _currentImageIndex) {
      _currentImageIndex += 1;
    }
    notifyListeners();
  }

  /// プレビューに表示する画像を切り替える。
  void showImageAt(int index) {
    if (index < 0 || index >= _images.length || index == _currentImageIndex) {
      return;
    }
    _currentImageIndex = index;
    notifyListeners();
  }

  // ---- 撮影場所の提案（Issue #46） ----

  void usePhotoLocation(LatLng location) {
    _adoptedLocation = location;
    _ignoredLocation = null;
    _refreshPhotoLocation();
    notifyListeners();
  }

  void ignorePhotoLocation(LatLng location) {
    _ignoredLocation = location;
    _refreshPhotoLocation();
    notifyListeners();
  }

  void restoreTappedLocation() {
    _ignoredLocation = _adoptedLocation;
    _adoptedLocation = null;
    _refreshPhotoLocation();
    notifyListeners();
  }

  /// 写真の変更後に再評価する。採用写真がなくなった場合だけ位置を戻す。
  void _refreshPhotoLocation() {
    _photoLocationResult = PhotoLocationSuggestions.evaluate(
      photoLocations: _photoLocations,
      tappedLocation: tappedLocation,
      adoptedLocation: _adoptedLocation,
      ignoredLocation: _ignoredLocation,
    );
    if (_photoLocationResult is RestoreTappedLocation) {
      _adoptedLocation = null;
      _photoLocationResult = PhotoLocationSuggestions.evaluate(
        photoLocations: _photoLocations,
        tappedLocation: tappedLocation,
        ignoredLocation: _ignoredLocation,
      );
      _notify('撮影場所の写真が外されたため、タップした場所に戻しました', isError: false);
    }
  }

  // ---- タグ（PS_03） ----

  /// `#タグ名` を空白・カンマ区切りで複数追加する。重複は無視する。
  void addTagsFromInput(String raw) {
    final added = <String>[];
    for (var token in raw.split(RegExp(r'[\s,、]+'))) {
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
    if (added.isEmpty) return;
    _tags.addAll(added);
    notifyListeners();
  }

  void removeTag(String tag) {
    if (_tags.remove(tag)) notifyListeners();
  }

  // ---- コンテスト応募 ----

  void setParticipateInContest(bool value) {
    _participateInContest = value;
    if (!value) _selectedContest = null;
    notifyListeners();
  }

  void selectContest(Contest? contest) {
    _selectedContest = contest;
    notifyListeners();
  }

  /// 最新のコンテスト一覧に合わせて選択を補正する（締切などで外れたら解除）。
  ///
  /// 一覧の描画中に呼ばれるため、ここでは再描画を要求しない。
  Contest? syncSelectedContest(List<Contest>? contests) {
    _selectedContest = contests
        ?.where((contest) => contest.id == _selectedContest?.id)
        .firstOrNull;
    return _selectedContest;
  }

  // ---- 送信 ----

  /// 入力を検証して投稿する。投稿できたら true を返す。
  Future<bool> submit({
    required String caption,
    required String locationName,
  }) async {
    if (!canSubmit) return false;
    // 一覧更新で選択が消えても、送信途中に通常投稿へ変えない。
    final selectedContest = _participateInContest ? _selectedContest : null;

    if (_participateInContest && selectedContest == null) {
      _notify('応募するコンテストを選択してください');
      return false;
    }
    if (_images.length > maxImages) {
      _notify('画像は最大$maxImages枚までです');
      return false;
    }
    // 元画像のサイズ検証（1枚30MB・合計100MB）— NFR_02 / Issue #99
    final sizeError = _imageService.validateSizes(_previewBytes);
    if (sizeError != null) {
      _notify(sizeError);
      return false;
    }
    final userId = _authRepository.currentUserId;
    if (userId == null) {
      _notify('ログインが必要です');
      return false;
    }

    _setPosting(true);

    try {
      if (selectedContest != null &&
          await _postRepository.hasContestEntry(selectedContest.id, userId)) {
        if (_disposed) return false;
        _setPosting(false);
        _notify('コンテストへの応募は1人1投稿までです');
        return false;
      }
    } catch (_) {
      if (_disposed) return false;
      _setPosting(false);
      _notify('応募状況を確認できませんでした');
      return false;
    }
    if (_disposed) return false;

    final location = _adoptedLocation ?? tappedLocation;
    final trimmedLocationName = locationName.trim();
    final post = Post(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      userId: userId,
      caption: caption,
      imageUrls: [],
      latitude: location.latitude,
      longitude: location.longitude,
      createdAt: DateTime.now(),
      locationName: trimmedLocationName.isEmpty ? null : trimmedLocationName,
      tags: List<String>.of(_tags),
    );

    final bool success;
    try {
      success = await _postRepository.createPost(
        post,
        List<XFile>.of(_images),
        contestId: selectedContest?.id,
      );
    } on CompressedImageTooLargeException catch (error) {
      // 圧縮後も上限以上の画像があり、アップロード前に中止した（Issue #99）
      if (_disposed) return false;
      _setPosting(false);
      _notify(error.message);
      return false;
    }
    if (_disposed) return false;

    if (!success) {
      _setPosting(false);
      _notify('投稿に失敗しました', isError: false);
    }
    return success;
  }

  void _setPosting(bool value) {
    _isPosting = value;
    notifyListeners();
  }

  void _notify(String message, {bool isError = true}) {
    if (_disposed) return;
    _notices.add(PostAddNotice(message, isError: isError));
  }

  @override
  void dispose() {
    _disposed = true;
    _notices.close();
    super.dispose();
  }
}
