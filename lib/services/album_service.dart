import 'package:afterglow_app/models/album.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// アルバムの読み書きを担うサービス（PS_02 / §3.6）。
/// アルバムは `albums/{albumId}` に保存する。
///
/// 閲覧は承認済みユーザー全員、作成・編集・削除は所有者（`ownerId`）のみ
/// という制約は Firestore ルール側で担保する（#18 / §7.2）。本サービスは
/// 所有者判定を [isOwnedBy] として公開し、UI が編集導線の出し分けに使う。
class AlbumService {
  AlbumService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  static const String albumsCollection = 'albums';

  CollectionReference<Map<String, dynamic>> get _albumsRef =>
      _firestore.collection(albumsCollection);

  /// アルバムを作成する。[album] の `id` が空文字なら Firestore が採番する。
  /// 作成された（もしくは指定された）アルバム ID を返す。失敗時は null。
  Future<String?> createAlbum(Album album) async {
    try {
      final docRef = album.id.isEmpty
          ? _albumsRef.doc()
          : _albumsRef.doc(album.id);
      await docRef.set(album.toMap());
      return docRef.id;
    } catch (_) {
      return null;
    }
  }

  /// 全アルバムを新しい順に購読する（一覧画面用）。
  /// 承認済みユーザーであれば他ユーザーのアルバムも閲覧できる（PS_02）。
  Stream<List<Album>> getAlbums() {
    return _albumsRef
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => Album.fromSnapshot(doc.id, doc.data()))
              .toList(growable: false),
        );
  }

  /// 指定ユーザーが所有するアルバムを新しい順に購読する。
  ///
  /// `where` と `orderBy` の複合インデックスを要求しないよう、並べ替えは
  /// クライアント側で行う（[PostService.getUserPosts] と同じ方針）。
  Stream<List<Album>> getUserAlbums(String ownerId) {
    return _albumsRef.where('ownerId', isEqualTo: ownerId).snapshots().map((
      snapshot,
    ) {
      final albums = snapshot.docs
          .map((doc) => Album.fromSnapshot(doc.id, doc.data()))
          .toList();
      albums.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return albums;
    });
  }

  /// 単一アルバムを購読する（詳細画面用）。存在しなければ null を流す。
  Stream<Album?> watchAlbum(String albumId) {
    return _albumsRef.doc(albumId).snapshots().map((snapshot) {
      final data = snapshot.data();
      if (data == null) {
        return null;
      }
      return Album.fromSnapshot(snapshot.id, data);
    });
  }

  /// アルバムに投稿を追加する。`arrayUnion` を使うため、同じ投稿を重ねて
  /// 追加しても重複しない。
  Future<bool> addPost(String albumId, String postId) async {
    try {
      await _albumsRef.doc(albumId).update({
        'postIds': FieldValue.arrayUnion([postId]),
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  /// アルバムから投稿を取り除く。投稿そのものは削除しない。
  Future<bool> removePost(String albumId, String postId) async {
    try {
      await _albumsRef.doc(albumId).update({
        'postIds': FieldValue.arrayRemove([postId]),
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  /// アルバムのタイトル・説明・カバー画像を更新する。所有者のみ成功する
  /// （ルールで担保）。[coverImageUrl] を省略した場合はカバー画像を変更しない。
  Future<bool> updateAlbum(
    String albumId, {
    required String title,
    required String description,
    String? coverImageUrl,
  }) async {
    try {
      await _albumsRef.doc(albumId).update({
        'title': title,
        'description': description,
        'coverImageUrl': ?coverImageUrl,
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  /// アルバムを削除する。含まれる投稿は削除しない（アルバムは投稿の集合を
  /// 参照するだけのため）。所有者のみ成功する（ルールで担保）。
  Future<bool> deleteAlbum(String albumId) async {
    try {
      await _albumsRef.doc(albumId).delete();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// [album] をログイン中ユーザー [uid] が編集できるかどうか。
  /// ルールと同じ条件を UI 側で先回りして判定するためのヘルパー。
  bool isOwnedBy(Album album, String? uid) =>
      uid != null && album.ownerId == uid;
}
