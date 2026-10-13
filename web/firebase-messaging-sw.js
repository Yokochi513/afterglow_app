// Firebase Cloud Messaging のバックグラウンド受信用 Service Worker（PS_07）。
//
// アプリのタブが閉じている／非アクティブなときに届いたプッシュ通知を表示する。
// 通知ペイロード（notification）付きのメッセージは SDK が自動で表示し、
// クリック時は Cloud Functions が設定した webpush.fcmOptions.link を開く。
// PushNotificationService が getToken 時にこのファイルを <base href> 相対で登録する。
//
// 設定値は lib/firebase_options.dart の web 用と同じ公開値（秘密情報ではない）。
// SDK のバージョンは firebase_core_web が読み込む JS SDK に合わせる。
importScripts('https://www.gstatic.com/firebasejs/12.15.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/12.15.0/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'AIzaSyB1eCFguYRHmGSz9j2J0mZKiUi9vphk2L0',
  appId: '1:169566722649:web:a097854abe411973986f48',
  messagingSenderId: '169566722649',
  projectId: 'flutter-afterglow',
  authDomain: 'flutter-afterglow.firebaseapp.com',
  storageBucket: 'flutter-afterglow.firebasestorage.app',
});

firebase.messaging();
