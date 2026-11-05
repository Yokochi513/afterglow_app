import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

/// Firebase Cloud Messaging（FCM）によるプッシュ通知を担うサービス（PS_07）。
///
/// 端末（ブラウザ）の FCM 登録トークンを `users/{uid}/private/messaging.tokens`
/// に保存する。Cloud Functions は `notifications` の作成を検知し、受信者の
/// トークンへプッシュ通知を送る。トークンは送信先を特定できる情報のため、
/// 本人のみ読み書きできる非公開サブコレクションに置く（firestore.rules 参照）。
///
/// Web ではバックグラウンド受信を `web/firebase-messaging-sw.js`
/// （Service Worker）が担い、フォアグラウンド受信は [onForegroundMessage] で
/// アプリ内に表示する。
class PushNotificationService {
  PushNotificationService({
    FirebaseFirestore? firestore,
    FirebaseMessaging? messaging,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _messagingOverride = messaging;

  final FirebaseFirestore _firestore;
  final FirebaseMessaging? _messagingOverride;

  /// FirebaseMessaging は生成時にネイティブ/JS 側へアクセスするため、
  /// トークン保存だけを使うテストで初期化されないよう遅延取得する。
  FirebaseMessaging get _messaging =>
      _messagingOverride ?? FirebaseMessaging.instance;

  static const String usersCollection = 'users';

  /// FCM 登録トークンを保持する非公開ドキュメント。
  static const String privateMessagingDoc = 'private/messaging';

  /// Web Push の VAPID 公開鍵（Firebase コンソール > Cloud Messaging >
  /// ウェブプッシュ証明書）。ビルド時に `--dart-define=FCM_VAPID_KEY=...` で渡す。
  /// 未設定の Web ビルドではプッシュ通知を無効として扱う（アプリ内通知は動く）。
  static const String vapidKey = String.fromEnvironment('FCM_VAPID_KEY');

  /// Web のバックグラウンド受信用 Service Worker。GitHub Pages ではサブパス
  /// （`/afterglow_app/`）配信のため、`<base href>` 相対で解決させる。
  static const String webServiceWorkerPath = 'firebase-messaging-sw.js';

  /// この環境でプッシュ通知を利用できるか。
  bool get isSupported => !kIsWeb || vapidKey.isNotEmpty;

  DocumentReference<Map<String, dynamic>> _messagingRef(String userId) =>
      _firestore.doc('$usersCollection/$userId/$privateMessagingDoc');

  /// 通知の許可状態を返す。
  Future<bool> isPermissionGranted() async {
    if (!isSupported) return false;
    final settings = await _messaging.getNotificationSettings();
    return _isAuthorized(settings.authorizationStatus);
  }

  /// 通知の許可をユーザーに求め、許可されたらトークンを登録する。
  /// ブラウザはユーザー操作を起点にしないと許可ダイアログを出さないことがあるため、
  /// ボタン押下から呼ぶ。登録できたら true。
  Future<bool> requestPermissionAndRegister(String userId) async {
    if (!isSupported) return false;
    final settings = await _messaging.requestPermission();
    if (!_isAuthorized(settings.authorizationStatus)) return false;
    return _registerCurrentToken(userId);
  }

  /// 既に許可済みならトークンを登録（更新）し、以後のトークン更新も保存する。
  /// 許可ダイアログは出さない（起動時に呼ぶ）。
  Future<void> registerIfPermitted(String userId) async {
    if (!await isPermissionGranted()) return;
    await _registerCurrentToken(userId);
    _messaging.onTokenRefresh.listen((token) => saveToken(userId, token));
  }

  /// アプリがフォアグラウンドのときに届いたメッセージ。
  Stream<RemoteMessage> get onForegroundMessage => FirebaseMessaging.onMessage;

  /// 通知をタップしてアプリが開かれたときのメッセージ（モバイル）。
  Stream<RemoteMessage> get onMessageOpenedApp =>
      FirebaseMessaging.onMessageOpenedApp;

  Future<bool> _registerCurrentToken(String userId) async {
    final token = await _messaging.getToken(
      vapidKey: kIsWeb ? vapidKey : null,
      serviceWorkerScriptPath: kIsWeb ? webServiceWorkerPath : null,
    );
    if (token == null || token.isEmpty) return false;
    await saveToken(userId, token);
    return true;
  }

  /// トークンを保存する。同一端末の重複登録を避けるため配列に union で追加する。
  Future<void> saveToken(String userId, String token) {
    return _messagingRef(userId).set({
      'tokens': FieldValue.arrayUnion([token]),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static bool _isAuthorized(AuthorizationStatus status) =>
      status == AuthorizationStatus.authorized ||
      status == AuthorizationStatus.provisional;
}

/// アプリがバックグラウンド/終了状態のときに届いたメッセージのハンドラ（モバイル）。
///
/// 通知ペイロード（`notification`）付きのメッセージは OS が通知を表示するため、
/// ここでは追加処理を行わない。`onBackgroundMessage` はトップレベル関数を要求する。
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {}
