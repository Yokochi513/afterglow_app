import 'package:afterglow_app/models/app_user.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

class UserService {
  UserService({FirebaseFirestore? firestore, FirebaseStorage? storage})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _storage = storage ?? FirebaseStorage.instance;

  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

  static const String usersCollection = 'users';

  /// 指定ユーザーの users ドキュメントを購読する。承認状態(`approved`)の
  /// 変化を AuthGate がリアルタイムに検知するために使用する。
  Stream<AppUser?> watchUser(String uid) {
    return _firestore.collection(usersCollection).doc(uid).snapshots().map((
      snapshot,
    ) {
      final data = snapshot.data();
      if (data == null) {
        return null;
      }
      return AppUser.fromSnapshot(snapshot.id, data);
    });
  }

  /// プロフィール情報（ユーザー名・自己紹介・プロフィール画像）を更新する。
  /// `profileImageUrl` を省略した場合は画像 URL を変更しない。
  Future<void> updateProfile(
    String uid, {
    required String username,
    required String bio,
    String? profileImageUrl,
  }) {
    return _firestore.collection(usersCollection).doc(uid).update({
      'username': username,
      'bio': bio,
      if (profileImageUrl != null) 'profileImageUrl': profileImageUrl,
    });
  }

  /// プロフィール画像を Storage(`profiles/{uid}/avatar.jpg`) にアップロードし、
  /// ダウンロード URL を返す。
  Future<String> uploadProfileImage(String uid, XFile imageFile) async {
    final storageRef = _storage.ref().child('profiles/$uid/avatar.jpg');
    final uploadTask = await storageRef.putData(
      await imageFile.readAsBytes(),
      SettableMetadata(contentType: 'image/jpeg'),
    );
    return uploadTask.ref.getDownloadURL();
  }
}
