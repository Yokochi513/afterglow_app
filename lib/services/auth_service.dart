import 'package:afterglow_app/models/app_user.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  AuthService({FirebaseAuth? auth, FirebaseFirestore? firestore})
    : _auth = auth ?? FirebaseAuth.instance,
      _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  static const String usersCollection = 'users';

  /// メールアドレス等の個人情報を格納する非公開サブコレクション。
  /// `users/{uid}` 本体は投稿者名表示のため全ログインユーザーに公開されるので、
  /// ここには分離して本人のみ読み書きできるようにする（firestore.rules 参照）。
  static const String privateProfileDoc = 'private/profile';

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  String? get currentUserId => _auth.currentUser?.uid;

  Future<UserCredential> signIn(String email, String password) {
    return _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  /// 新規登録。Auth ユーザー作成後、Firestore に未承認(`approved: false`)の
  /// 公開プロフィール（users/{uid}）とメールアドレス等を含む非公開プロフィール
  /// （users/{uid}/private/profile）をバッチで作成する。この作成を Cloud
  /// Functions が検知し、管理者へ承認依頼メールを送信する。
  Future<UserCredential> register(
    String email,
    String password,
    String username,
  ) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    final uid = credential.user!.uid;
    final user = AppUser(
      id: uid,
      username: username,
      createdAt: DateTime.now(),
    );

    final batch = _firestore.batch();
    batch.set(_firestore.collection(usersCollection).doc(uid), user.toMap());
    batch.set(_firestore.doc('$usersCollection/$uid/$privateProfileDoc'), {
      'email': email,
      'emailNotification': true,
    });
    await batch.commit();

    return credential;
  }

  Future<void> signOut() => _auth.signOut();
}
