import 'dart:async';

import 'package:afterglow_app/pages/album_list_page.dart';
import 'package:afterglow_app/pages/contest_list_page.dart';
import 'package:afterglow_app/pages/event_page.dart';
import 'package:afterglow_app/pages/feed_page.dart';
import 'package:afterglow_app/pages/map_screen.dart';
import 'package:afterglow_app/pages/notification_page.dart';
import 'package:afterglow_app/pages/profile_page.dart';
import 'package:afterglow_app/services/auth_service.dart';
import 'package:afterglow_app/services/push_notification_service.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

/// 承認済みユーザーのアプリ本体。
///
/// `BottomNavigationBar` で 5 つのタブを切り替える（設計書 §4.2）。
/// - 0: Feed（FR_02）… [FeedPage]
/// - 1: Map（FR_03）… 既存 [MapScreen]
/// - 2: Album（PS_02）… [AlbumListPage]（承認済みユーザー全員のアルバム）
/// - 3: Event（FR_05）… [EventPage]（承認済みユーザー全員のイベント）
/// - 4: Contest（Issue #69）… [ContestListPage]（承認済みユーザー全員のコンテスト）
///
/// 投稿（FR_07）はタブを持たず、マップ画面の地図タップから開く [ProfilePage] は
/// 既存の Profile 導線（本ウィジェット外）から表示する。
///
/// タブ切替でスクロール位置などの状態を破棄しないよう [IndexedStack] で保持する。
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  /// タブのインデックス定義（本ウィジェットで参照するもののみ）。
  static const int _mapIndex = 1;

  /// 現在表示中のタブ。既存挙動を保つため Map を初期表示にする。
  int _currentIndex = _mapIndex;

  final PushNotificationService _push = PushNotificationService();
  final List<StreamSubscription<RemoteMessage>> _pushSubscriptions = [];

  @override
  void initState() {
    super.initState();
    _startPushNotifications();
  }

  @override
  void dispose() {
    for (final subscription in _pushSubscriptions) {
      subscription.cancel();
    }
    super.dispose();
  }

  /// プッシュ通知（PS_07）の受信を開始する。許可済みの端末ならトークンを
  /// 登録し直し、フォアグラウンド受信はスナックバーで知らせる。
  /// 許可の要求は通知一覧の「有効にする」から行う（起動直後に許可ダイアログを
  /// 出さない）。プッシュ通知が使えない環境でもアプリ本体は動かす。
  Future<void> _startPushNotifications() async {
    final uid = AuthService().currentUserId;
    if (uid == null || !_push.isSupported) return;
    try {
      await _push.registerIfPermitted(uid);
      _pushSubscriptions
        ..add(_push.onForegroundMessage.listen(_showForegroundMessage))
        ..add(_push.onMessageOpenedApp.listen((_) => _openNotifications()));
    } catch (_) {
      // 通知非対応ブラウザ等。アプリ内通知は引き続き利用できる。
    }
  }

  void _showForegroundMessage(RemoteMessage message) {
    if (!mounted) return;
    // タイトルはアプリ名固定なので本文だけを出す（Functions の onNotificationCreated）
    final body = message.notification?.body ?? '';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(body.isEmpty ? '新しい通知があります' : body),
        action: SnackBarAction(label: '見る', onPressed: _openNotifications),
      ),
    );
  }

  void _openNotifications() {
    if (!mounted) return;
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const NotificationPage()));
  }

  /// [IndexedStack] に並べる各タブの本体。
  static const List<Widget> _pages = <Widget>[
    FeedPage(), // 0: Feed（FR_02）
    MapScreen(), // 1: Map
    AlbumListPage(), // 2: Album（PS_02）
    EventPage(), // 3: Event（FR_05）
    ContestListPage(), // 4: Contest（Issue #69）
  ];

  void _onTabTapped(int index) {
    if (index == _currentIndex) return;
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _pages),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: _onTabTapped,
        type: BottomNavigationBarType.fixed,
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.dynamic_feed_outlined),
            label: 'Feed',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.map_outlined), label: 'Map'),
          BottomNavigationBarItem(
            icon: Icon(Icons.photo_album_outlined),
            label: 'Album',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.event_outlined),
            label: 'Event',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.emoji_events_outlined),
            label: 'Contest',
          ),
        ],
      ),
    );
  }
}
