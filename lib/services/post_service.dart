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
    List<String> imageUrls = [];
    for (final imageFile in imageFiles) {
      final storageRef = _storage.ref().child(
        'posts/${post.userId}/${post.id}.jpg',
      );

      final uploadTask = await storageRef.putData(
        await imageFile.readAsBytes(),
      );
      final downloadUrl = await uploadTask.ref.getDownloadURL();
      imageUrls.add(downloadUrl);
    }

    await _firestore.collection(postsCollection).doc(post.id).set({
      'userId': post.userId,
      'caption': post.caption,
      'imageUrls': imageUrls,
      'latitude': post.latitude,
      'longitude': post.longitude,
      'createdAt': Timestamp.fromDate(post.createdAt),
    });
    return true;
  }

  Stream<List<Post>> getPosts() {
    return _firestore.collection(postsCollection).snapshots().map((event) {
      return event.docs.reversed
          .map((document) => Post.fromSnapshot(document.id, document.data()))
          .toList(growable: false);
    });
  }
}
