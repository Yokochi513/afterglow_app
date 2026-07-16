import 'package:afterglow_app/models/album.dart';
import 'package:afterglow_app/services/album_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AlbumService', () {
    late FakeFirebaseFirestore firestore;
    late AlbumService service;

    setUp(() {
      firestore = FakeFirebaseFirestore();
      service = AlbumService(firestore: firestore);
    });

    CollectionReference<Map<String, dynamic>> albumsRef() =>
        firestore.collection(AlbumService.albumsCollection);

    Album album({
      String id = '',
      String ownerId = 'user-1',
      String title = '春の撮影会',
      String description = '',
      List<String> postIds = const [],
      String? coverImageUrl,
      DateTime? createdAt,
    }) {
      return Album(
        id: id,
        ownerId: ownerId,
        title: title,
        description: description,
        postIds: postIds,
        coverImageUrl: coverImageUrl,
        createdAt: createdAt ?? DateTime(2026, 7, 15, 12),
      );
    }

    test('createAlbum stores the album and returns a generated id', () async {
      final albumId = await service.createAlbum(
        album(description: '桜を撮りに行った日'),
      );

      expect(albumId, isNotNull);

      final doc = await albumsRef().doc(albumId!).get();
      expect(doc.exists, isTrue);

      final data = doc.data()!;
      expect(data['ownerId'], 'user-1');
      expect(data['title'], '春の撮影会');
      expect(data['description'], '桜を撮りに行った日');
      expect(data['postIds'], isEmpty);
      expect(data['coverImageUrl'], isNull);
      expect(data['createdAt'], isA<Timestamp>());
    });

    test('createAlbum uses the provided id when it is not empty', () async {
      final albumId = await service.createAlbum(album(id: 'fixed-id'));

      expect(albumId, 'fixed-id');
      expect((await albumsRef().doc('fixed-id').get()).exists, isTrue);
    });

    test(
      'getAlbums returns every album in descending createdAt order',
      () async {
        await service.createAlbum(
          album(id: 'a-old', title: '古い', createdAt: DateTime(2026, 7, 10)),
        );
        await service.createAlbum(
          album(
            id: 'a-new',
            ownerId: 'user-2',
            title: '新しい',
            createdAt: DateTime(2026, 7, 14),
          ),
        );

        final albums = await service.getAlbums().first;

        // 表示範囲は「全体」なので、他ユーザー(user-2)のアルバムも含まれる。
        expect(albums.map((a) => a.id).toList(), ['a-new', 'a-old']);
      },
    );

    test(
      'getUserAlbums is scoped to the owner and sorted newest first',
      () async {
        await service.createAlbum(
          album(id: 'mine-old', createdAt: DateTime(2026, 7, 10)),
        );
        await service.createAlbum(
          album(id: 'mine-new', createdAt: DateTime(2026, 7, 14)),
        );
        await service.createAlbum(album(id: 'theirs', ownerId: 'user-2'));

        final albums = await service.getUserAlbums('user-1').first;

        expect(albums.map((a) => a.id).toList(), ['mine-new', 'mine-old']);
      },
    );

    test('watchAlbum emits the album and null when it is missing', () async {
      await service.createAlbum(album(id: 'a-1', title: '夏合宿'));

      expect((await service.watchAlbum('a-1').first)!.title, '夏合宿');
      expect(await service.watchAlbum('missing').first, isNull);
    });

    test('addPost appends the post id without duplicating it', () async {
      await service.createAlbum(album(id: 'a-1'));

      expect(await service.addPost('a-1', 'post-1'), isTrue);
      expect(await service.addPost('a-1', 'post-2'), isTrue);
      // 同じ投稿を重ねて追加しても重複しない（arrayUnion）。
      expect(await service.addPost('a-1', 'post-1'), isTrue);

      final stored = await service.watchAlbum('a-1').first;
      expect(stored!.postIds, ['post-1', 'post-2']);
    });

    test('removePost drops only the given post id', () async {
      await service.createAlbum(
        album(id: 'a-1', postIds: const ['post-1', 'post-2']),
      );

      expect(await service.removePost('a-1', 'post-1'), isTrue);

      final stored = await service.watchAlbum('a-1').first;
      expect(stored!.postIds, ['post-2']);
    });

    test('updateAlbum changes title and description', () async {
      await service.createAlbum(album(id: 'a-1'));

      final result = await service.updateAlbum(
        'a-1',
        title: '編集後',
        description: '説明も更新',
      );
      expect(result, isTrue);

      final stored = await service.watchAlbum('a-1').first;
      expect(stored!.title, '編集後');
      expect(stored.description, '説明も更新');
    });

    test('updateAlbum keeps the cover image when it is omitted', () async {
      await service.createAlbum(
        album(id: 'a-1', coverImageUrl: 'https://example.com/cover.jpg'),
      );

      await service.updateAlbum('a-1', title: '編集後', description: '');

      final stored = await service.watchAlbum('a-1').first;
      expect(stored!.coverImageUrl, 'https://example.com/cover.jpg');
    });

    test('deleteAlbum removes the album document', () async {
      await service.createAlbum(album(id: 'a-1'));

      expect(await service.deleteAlbum('a-1'), isTrue);
      expect((await albumsRef().doc('a-1').get()).exists, isFalse);
    });

    test('isOwnedBy is true only for the owner uid', () {
      final target = album(id: 'a-1');

      expect(service.isOwnedBy(target, 'user-1'), isTrue);
      expect(service.isOwnedBy(target, 'user-2'), isFalse);
      expect(service.isOwnedBy(target, null), isFalse);
    });
  });
}
