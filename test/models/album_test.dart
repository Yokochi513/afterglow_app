import 'package:afterglow_app/models/album.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Album.fromSnapshot', () {
    test('maps every field of a full document', () {
      final album = Album.fromSnapshot('a-1', {
        'ownerId': 'user-1',
        'title': '春の撮影会',
        'description': '桜を撮りに行った日',
        'postIds': ['post-1', 'post-2'],
        'coverImageUrl': 'https://example.com/cover.jpg',
        'createdAt': Timestamp.fromDate(DateTime(2026, 7, 15, 12)),
      });

      expect(album.id, 'a-1');
      expect(album.ownerId, 'user-1');
      expect(album.title, '春の撮影会');
      expect(album.description, '桜を撮りに行った日');
      expect(album.postIds, ['post-1', 'post-2']);
      expect(album.coverImageUrl, 'https://example.com/cover.jpg');
      expect(album.createdAt, DateTime(2026, 7, 15, 12));
    });

    test('falls back to defaults for a document with missing fields', () {
      final album = Album.fromSnapshot('a-1', const {});

      expect(album.ownerId, '');
      expect(album.title, '');
      expect(album.description, '');
      expect(album.postIds, isEmpty);
      expect(album.coverImageUrl, isNull);
      expect(album.createdAt, isA<DateTime>());
    });
  });

  group('Album.toMap', () {
    test('serialises createdAt as a Timestamp and keeps a null cover', () {
      final map = Album(
        id: 'a-1',
        ownerId: 'user-1',
        title: '夏合宿',
        description: '',
        createdAt: DateTime(2026, 7, 15, 12),
      ).toMap();

      expect(map['ownerId'], 'user-1');
      expect(map['title'], '夏合宿');
      expect(map['description'], '');
      expect(map['postIds'], isEmpty);
      expect(map['coverImageUrl'], isNull);
      expect(map['createdAt'], Timestamp.fromDate(DateTime(2026, 7, 15, 12)));
      // id はドキュメント ID なので本文には含めない。
      expect(map.containsKey('id'), isFalse);
    });

    test('round-trips through fromSnapshot', () {
      final original = Album(
        id: 'a-1',
        ownerId: 'user-1',
        title: '春の撮影会',
        description: '桜',
        postIds: const ['post-1'],
        coverImageUrl: 'https://example.com/cover.jpg',
        createdAt: DateTime(2026, 7, 15, 12),
      );

      final restored = Album.fromSnapshot('a-1', original.toMap());

      expect(restored.ownerId, original.ownerId);
      expect(restored.title, original.title);
      expect(restored.description, original.description);
      expect(restored.postIds, original.postIds);
      expect(restored.coverImageUrl, original.coverImageUrl);
      expect(restored.createdAt, original.createdAt);
    });
  });
}
