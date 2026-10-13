import 'package:afterglow_app/models/notification.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// アプリ内通知の読み取り・既読化と、メール通知設定を担うサービス（§6.6）。
///
/// 通知ドキュメント（`notifications/{notificationId}`・§3.9）の生成は Cloud
/// Functions のトリガーが行う。クライアントは受信者本人として読み取りと
/// `isRead` の既読化だけが許可されている（firestore.rules 参照）。
///
/// メール通知の on/off（PS_07）は `users/{uid}/private/profile.emailNotification`
/// に保存する（§3.2.1）。Functions の週次ダイジェストメールがこの値を尊重する。
class NotificationService {
  NotificationService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  static const String notificationsCollection = 'notifications';
  static const String usersCollection = 'users';

  /// メールアドレス・メール通知設定を持つ非公開ドキュメント（§3.2.1）。
  static const String privateProfileDoc = 'private/profile';

  /// 一覧に表示する通知の最大件数（新しい順）。
  static const int listLimit = 50;

  CollectionReference<Map<String, dynamic>> get _notificationsRef =>
      _firestore.collection(notificationsCollection);

  Query<Map<String, dynamic>> _recipientQuery(String userId) =>
      _notificationsRef.where('recipientId', isEqualTo: userId);

  /// 指定ユーザー宛ての通知を新しい順に購読する。
  Stream<List<AppNotification>> getNotifications(String userId) {
    return _recipientQuery(userId)
        .orderBy('createdAt', descending: true)
        .limit(listLimit)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => AppNotification.fromSnapshot(doc.id, doc.data()))
              .toList(growable: false),
        );
  }

  /// 指定ユーザー宛ての未読通知の件数を購読する（ベルのバッジ表示用）。
  Stream<int> watchUnreadCount(String userId) {
    return _recipientQuery(userId)
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  /// 通知を既読にする。
  Future<void> markAsRead(String notificationId) {
    return _notificationsRef.doc(notificationId).update({'isRead': true});
  }

  /// 指定ユーザー宛ての未読通知をすべて既読にする。
  Future<void> markAllAsRead(String userId) async {
    final unread = await _recipientQuery(
      userId,
    ).where('isRead', isEqualTo: false).get();
    if (unread.docs.isEmpty) return;

    final batch = _firestore.batch();
    for (final doc in unread.docs) {
      batch.update(doc.reference, {'isRead': true});
    }
    await batch.commit();
  }

  DocumentReference<Map<String, dynamic>> _privateProfileRef(String userId) =>
      _firestore.doc('$usersCollection/$userId/$privateProfileDoc');

  /// メール通知の on/off を購読する。未設定なら既定の `true`（§3.2.1）。
  Stream<bool> watchEmailNotification(String userId) {
    return _privateProfileRef(userId).snapshots().map(
      (snapshot) => snapshot.data()?['emailNotification'] ?? true,
    );
  }

  /// メール通知の on/off を更新する。
  Future<void> setEmailNotification(String userId, bool enabled) {
    return _privateProfileRef(
      userId,
    ).set({'emailNotification': enabled}, SetOptions(merge: true));
  }
}
