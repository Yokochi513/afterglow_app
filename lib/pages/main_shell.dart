import 'package:afterglow_app/pages/album_list_page.dart';
import 'package:afterglow_app/pages/contest_list_page.dart';
import 'package:afterglow_app/pages/event_page.dart';
import 'package:afterglow_app/pages/feed_page.dart';
import 'package:afterglow_app/pages/map_screen.dart';
import 'package:afterglow_app/pages/profile_page.dart';
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
