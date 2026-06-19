import 'package:afterglow_app/models/app_user.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class UserService {
  UserService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

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
}
