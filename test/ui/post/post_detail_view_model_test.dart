import 'package:afterglow_app/data/models/post.dart';
import 'package:afterglow_app/data/repositories/auth_repository.dart';
import 'package:afterglow_app/data/repositories/contest_repository.dart';
import 'package:afterglow_app/data/repositories/post_repository.dart';
import 'package:afterglow_app/data/repositories/user_repository.dart';
import 'package:afterglow_app/ui/post/post_detail_view_model.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:firebase_storage_mocks/firebase_storage_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

/// 更新・削除の呼び出しを記録する PostRepository。
class _RecordingPostRepository extends PostRepository {
  _RecordingPostRepository(FakeFirebaseFirestore firestore)
    : super(firestore: firestore, storage: MockFirebaseStorage());

  bool result = true;
  String? caption;
  List<String>? imageUrls;
  List<String>? removedImageUrls;
  double? latitude;
  bool deleted = false;

  @override
  Future<bool> updatePost(
    Post post, {
    required String caption,
    required List<String> imageUrls,
    required List<String> removedImageUrls,
    double? latitude,
    double? longitude,
  }) async {
    this.caption = caption;
    this.imageUrls = imageUrls;
    this.removedImageUrls = removedImageUrls;
    this.latitude = latitude;
    return result;
  }

  @override
  Future<bool> deletePost(Post post) async {
    deleted = true;
    return result;
  }
}

Post _post({String userId = 'owner'}) => Post(
  id: 'post-1',
  userId: userId,
  caption: '元の説明',
  imageUrls: const ['a', 'b', 'c'],
  latitude: 35.0,
  longitude: 139.0,
  createdAt: DateTime(2026, 4, 18),
);

void main() {
  late FakeFirebaseFirestore firestore;
  late _RecordingPostRepository postRepository;

  PostDetailViewModel build({String viewer = 'owner', Post? post}) {
    final vm = PostDetailViewModel(
      post: post ?? _post(),
      authRepository: AuthRepository(
        auth: MockFirebaseAuth(signedIn: true, mockUser: MockUser(uid: viewer)),
        firestore: firestore,
      ),
      postRepository: postRepository,
      userRepository: UserRepository(
        firestore: firestore,
        storage: MockFirebaseStorage(),
      ),
      contestRepository: ContestRepository(
        firestore: firestore,
        postRepository: postRepository,
      ),
    );
    addTearDown(vm.dispose);
    return vm;
  }

  setUp(() {
    firestore = FakeFirebaseFirestore();
    postRepository = _RecordingPostRepository(firestore);
  });

  test('通常投稿は投稿者本人だけが編集・削除できる', () async {
    final owner = build();
    await owner.loadManagePermission();
    expect(owner.canManagePost, isTrue);

    final other = build(viewer: 'someone');
    await other.loadManagePermission();
    expect(other.canManagePost, isFalse);
  });

  test('画像の移動・削除は取り消すと編集前に戻る', () {
    final vm = build();
    vm.enterEditMode(caption: '元の説明');

    vm.showImageAt(2);
    vm.moveCurrentImage(0);
    expect(vm.imageUrls, ['c', 'a', 'b']);
    expect(vm.currentImageIndex, 0);

    expect(vm.deleteCurrentImage(), isTrue);
    expect(vm.imageUrls, ['a', 'b']);

    vm.changePosition(const LatLng(34.6, 133.9));
    expect(vm.cancelEdit(), '元の説明');
    expect(vm.isEditing, isFalse);
    expect(vm.imageUrls, ['a', 'b', 'c']);
    expect(vm.position, const LatLng(35.0, 139.0));
  });

  test('最後の 1 枚は削除できない', () {
    final vm = build(
      post: Post(
        id: 'post-1',
        userId: 'owner',
        caption: '',
        imageUrls: const ['only'],
        latitude: 35.0,
        longitude: 139.0,
        createdAt: DateTime(2026, 4, 18),
      ),
    );
    vm.enterEditMode(caption: '');
    expect(vm.deleteCurrentImage(), isFalse);
    expect(vm.imageUrls, ['only']);
  });

  test('保存すると並び順・削除画像・選び直した位置を送り、編集を終える', () async {
    final vm = build();
    vm.enterEditMode(caption: '元の説明');
    vm.showImageAt(1);
    expect(vm.deleteCurrentImage(), isTrue);
    vm.changePosition(const LatLng(34.6, 133.9));

    expect(await vm.saveEdit(caption: '新しい説明'), isTrue);
    expect(postRepository.caption, '新しい説明');
    expect(postRepository.imageUrls, ['a', 'c']);
    expect(postRepository.removedImageUrls, ['b']);
    expect(postRepository.latitude, 34.6);
    expect(vm.isEditing, isFalse);
    expect(vm.isSaving, isFalse);
  });

  test('位置を選び直さなければ緯度経度は送らない', () async {
    final vm = build();
    vm.enterEditMode(caption: '');
    await vm.saveEdit(caption: '');
    expect(postRepository.latitude, isNull);
  });

  test('削除に失敗したら削除中を解除する', () async {
    final vm = build();
    postRepository.result = false;
    expect(await vm.deletePost(), isFalse);
    expect(postRepository.deleted, isTrue);
    expect(vm.isDeleting, isFalse);
  });
}
