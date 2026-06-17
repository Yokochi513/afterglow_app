import 'package:afterglow_app/models/post.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

class PostService {
  PostService({FirebaseFirestore? firestore, FirebaseStorage? storage})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _storage = storage ?? FirebaseStorage.instance;

  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

  static const String postsCollection = 'posts';

  Future<bool> createPost(Post post, List<XFile> imageFiles) async {
    try {
      final imageUrls = await Future.wait(
        imageFiles.asMap().entries.map((entry) async {
          final index = entry.key;
          final imageFile = entry.value;
          final storageRef = _storage.ref().child(
            'posts/${post.userId}/${post.id}_$index.jpg',
          );

          final uploadTask = await storageRef.putData(
            await imageFile.readAsBytes(),
            SettableMetadata(
              contentType: 'image/jpeg',
              // 投稿画像は不変なので長期キャッシュを許可し、CDN/クライアント
              // キャッシュを効かせて2回目以降のロードを高速化する
              cacheControl: 'public, max-age=31536000, immutable',
            ),
          );
          return uploadTask.ref.getDownloadURL();
        }),
      );

      await _firestore.collection(postsCollection).doc(post.id).set({
        'userId': post.userId,
        'caption': post.caption,
        'imageUrls': imageUrls,
        'latitude': post.latitude,
        'longitude': post.longitude,
        'createdAt': Timestamp.fromDate(post.createdAt),
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  Stream<List<Post>> getPosts() {
    return _firestore.collection(postsCollection).snapshots().map((event) {
      return event.docs.reversed
          .map((document) => Post.fromSnapshot(document.id, document.data()))
          .toList(growable: false);
    });
  }
}
