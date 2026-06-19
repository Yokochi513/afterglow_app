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

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  String? get currentUserId => _auth.currentUser?.uid;

  Future<UserCredential> signIn(String email, String password) {
    return _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  /// 新規登録。Auth ユーザー作成後、Firestore に未承認(`approved: false`)の
  /// users ドキュメントを作成する。このドキュメント作成を Cloud Functions が
  /// 検知し、管理者へ承認依頼メールを送信する。
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
      email: email,
      createdAt: DateTime.now(),
    );

    await _firestore
        .collection(usersCollection)
        .doc(uid)
        .set(user.toMap());

    return credential;
  }

  Future<void> signOut() => _auth.signOut();
}
