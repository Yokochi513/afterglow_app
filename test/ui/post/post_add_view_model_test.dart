import 'dart:typed_data';

import 'package:afterglow_app/data/models/contest.dart';
import 'package:afterglow_app/data/models/post.dart';
import 'package:afterglow_app/data/repositories/auth_repository.dart';
import 'package:afterglow_app/data/repositories/contest_repository.dart';
import 'package:afterglow_app/data/repositories/post_repository.dart';
import 'package:afterglow_app/data/services/image_service.dart';
import 'package:afterglow_app/ui/post/post_add_view_model.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:firebase_storage_mocks/firebase_storage_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';

/// EXIF を読まずに、指定した撮影位置を順に返す画像サービス。
class _FakeImageService extends ImageService {
  _FakeImageService([this.locations = const []]);

  final List<LatLng?> locations;
  int _reads = 0;

  @override
  Future<LatLng?> extractGpsLocation(Uint8List bytes) async {
    final index = _reads++;
    return index < locations.length ? locations[index] : null;
  }
}

/// 送信内容を記録し、Storage へのアップロードを行わない PostRepository。
class _RecordingPostRepository extends PostRepository {
  _RecordingPostRepository(FakeFirebaseFirestore firestore)
    : super(firestore: firestore, storage: MockFirebaseStorage());

  Post? submitted;
  List<XFile>? submittedImages;
  String? submittedContestId;
  bool result = true;
  bool hasEntry = false;

  /// 送信時に投げる例外（圧縮後のサイズ超過などの再現用）。
  Object? error;

  @override
  Future<bool> hasContestEntry(String contestId, String userId) async =>
      hasEntry;

  @override
  Future<bool> createPost(
    Post post,
    List<XFile> imageFiles, {
    String? contestId,
    bool stayAnonymous = false,
  }) async {
    submitted = post;
    submittedImages = imageFiles;
    submittedContestId = contestId;
    if (error != null) throw error!;
    return result;
  }
}

XFile _image(String name) =>
    XFile.fromData(Uint8List(16), name: name, path: name);

const _tapped = LatLng(35.0, 139.0);

void main() {
  late FakeFirebaseFirestore firestore;
  late _RecordingPostRepository postRepository;
  late List<PostAddNotice> notices;

  PostAddViewModel build({
    bool signedIn = true,
    List<LatLng?> photoLocations = const [],
  }) {
    final viewModel = PostAddViewModel(
      tappedLocation: _tapped,
      postRepository: postRepository,
      contestRepository: ContestRepository(
        firestore: firestore,
        postRepository: postRepository,
      ),
      authRepository: AuthRepository(
        auth: MockFirebaseAuth(
          signedIn: signedIn,
          mockUser: MockUser(uid: 'user-1'),
        ),
        firestore: firestore,
      ),
      imageService: _FakeImageService(photoLocations),
    );
    viewModel.notices.listen(notices.add);
    addTearDown(viewModel.dispose);
    return viewModel;
  }

  setUp(() {
    firestore = FakeFirebaseFirestore();
    postRepository = _RecordingPostRepository(firestore);
    notices = [];
  });

  group('画像', () {
    test('許可されていない拡張子は外して通知する', () async {
      final vm = build();
      await vm.addImages([_image('a.jpg'), _image('b.gif')]);
      await pumpEventQueue();

      expect(vm.images.map((image) => image.name), ['a.jpg']);
      expect(notices.single.message, contains('JPEG / PNG / BMP / HEIC'));
    });

    test('上限を超えた分は追加せず通知する', () async {
      final vm = build();
      await vm.addImages([
        for (var i = 0; i < PostAddViewModel.defaultMaxImages + 2; i++)
          _image('$i.jpg'),
      ]);
      await pumpEventQueue();

      expect(vm.images, hasLength(PostAddViewModel.defaultMaxImages));
      expect(vm.canAddImages, isFalse);
      expect(vm.checkCanPickImages(), isFalse);
      await pumpEventQueue();
      expect(notices.map((n) => n.message), everyElement(contains('最大10枚')));
    });

    test('並び替えで表示中の画像を追いかけ、削除で表示位置を範囲内に収める', () async {
      final vm = build();
      await vm.loadInitialImages([
        _image('a.jpg'),
        _image('b.jpg'),
        _image('c.jpg'),
      ]);

      vm.showImageAt(0);
      vm.reorderImage(0, 2);
      expect(vm.images.map((image) => image.name), ['b.jpg', 'c.jpg', 'a.jpg']);
      expect(vm.currentImageIndex, 2);

      vm.removeImage(2);
      expect(vm.images.map((image) => image.name), ['b.jpg', 'c.jpg']);
      expect(vm.currentImageIndex, 1);
    });
  });

  test('タグは # と区切り文字を取り除き、重複を無視して追加する', () {
    final vm = build();
    vm.addTagsFromInput('#夜景 #桜、夜景,  #港 ');
    expect(vm.tags, ['夜景', '桜', '港']);

    vm.removeTag('桜');
    expect(vm.tags, ['夜景', '港']);
  });

  test('撮影場所を採用して投稿すると、その位置で送信する', () async {
    const photo = LatLng(34.6, 133.9);
    final vm = build(photoLocations: [photo]);
    await vm.loadInitialImages([_image('a.jpg')]);

    vm.usePhotoLocation(photo);
    final posted = await vm.submit(caption: '夕焼け', locationName: ' 岡山城 ');

    expect(posted, isTrue);
    expect(postRepository.submitted!.latitude, photo.latitude);
    expect(postRepository.submitted!.longitude, photo.longitude);
    expect(postRepository.submitted!.caption, '夕焼け');
    expect(postRepository.submitted!.locationName, '岡山城');
    expect(postRepository.submittedImages, hasLength(1));
  });

  group('送信の検証', () {
    test('画像がなければ送信しない', () async {
      final vm = build();
      expect(vm.canSubmit, isFalse);
      expect(await vm.submit(caption: '', locationName: ''), isFalse);
      expect(postRepository.submitted, isNull);
    });

    test('未ログインなら通知して送信しない', () async {
      final vm = build(signedIn: false);
      await vm.loadInitialImages([_image('a.jpg')]);

      expect(await vm.submit(caption: '', locationName: ''), isFalse);
      await pumpEventQueue();
      expect(notices.single.message, 'ログインが必要です');
      expect(postRepository.submitted, isNull);
    });

    test('応募をオンにしてコンテスト未選択なら送信しない', () async {
      final vm = build();
      await vm.loadInitialImages([_image('a.jpg')]);
      vm.setParticipateInContest(true);

      expect(await vm.submit(caption: '', locationName: ''), isFalse);
      await pumpEventQueue();
      expect(notices.single.message, '応募するコンテストを選択してください');
    });

    test('応募済みのコンテストには送信せず、送信中を解除する', () async {
      final vm = build();
      await vm.loadInitialImages([_image('a.jpg')]);
      postRepository.hasEntry = true;
      final now = DateTime.now();
      vm.setParticipateInContest(true);
      vm.selectContest(
        Contest(
          id: 'contest-1',
          creatorId: 'creator',
          title: '夕焼けコンテスト',
          description: '',
          entryDeadline: now.add(const Duration(days: 1)),
          votingDeadline: now.add(const Duration(days: 2)),
          createdAt: now,
          updatedAt: now,
        ),
      );

      expect(await vm.submit(caption: '', locationName: ''), isFalse);
      await pumpEventQueue();
      expect(notices.single.message, 'コンテストへの応募は1人1投稿までです');
      expect(vm.isPosting, isFalse);
      expect(postRepository.submitted, isNull);
    });

    test('送信に失敗したら送信中を解除して通知する', () async {
      final vm = build();
      await vm.loadInitialImages([_image('a.jpg')]);
      postRepository.result = false;

      expect(await vm.submit(caption: '', locationName: ''), isFalse);
      await pumpEventQueue();
      expect(vm.isPosting, isFalse);
      expect(notices.single.message, '投稿に失敗しました');
    });

    test('圧縮後も10MB以上の画像があれば理由を通知し、送信中を解除する', () async {
      final vm = build();
      await vm.loadInitialImages([_image('a.jpg')]);
      postRepository.error = const CompressedImageTooLargeException();

      expect(await vm.submit(caption: '', locationName: ''), isFalse);
      await pumpEventQueue();

      expect(vm.isPosting, isFalse);
      expect(notices.single.message, '圧縮後も10MBを超える画像があるため投稿できません');
      expect(notices.single.isError, isTrue);
    });
  });
}
