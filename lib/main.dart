import 'package:afterglow_app/app/app.dart';
import 'package:afterglow_app/app/dependencies.dart';
import 'package:afterglow_app/data/services/push_notification_service.dart';
import 'package:afterglow_app/firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // モバイルのバックグラウンド受信（PS_07）。Web は firebase-messaging-sw.js が担う。
  if (!kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS)) {
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  }
  runApp(MyApp(dependencies: AppDependencies()));
}
