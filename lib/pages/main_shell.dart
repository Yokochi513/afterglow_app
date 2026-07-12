import 'package:afterglow_app/pages/map_screen.dart';
import 'package:afterglow_app/pages/profile_page.dart';
import 'package:afterglow_app/widgets/post_add_dialog.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

/// 承認済みユーザーのアプリ本体。
///
/// `BottomNavigationBar` で 5 つのタブを切り替える（設計書 §4.2）。
/// - 0: Feed（FR_02・後続 Issue #10 で実装）… 現状はプレースホルダ
/// - 1: Map（FR_03）… 既存 [MapScreen]
/// - 2: 投稿（FR_07）… タブ選択で [PostAddDialog] を開く（タブは切り替えない）
/// - 3: Event（FR_05・後続 Issue #15 で実装）… 現状はプレースホルダ
/// - 4: Profile（FR_06）… 既存 [ProfilePage]
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
  static const int _postIndex = 2;

  /// 投稿タブから開くダイアログの既定位置（[MapScreen] の既定位置に揃える）。
  static const LatLng _defaultPostLocation = LatLng(34.669478, 133.951104);

  /// 現在表示中のタブ。既存挙動を保つため Map を初期表示にする。
  int _currentIndex = _mapIndex;

  /// [IndexedStack] に並べる各タブの本体。
  /// 投稿タブ（index 2）はダイアログを開くだけで画面を持たないため、
  /// 表示されることのないダミーを置いてインデックスを揃える。
  static const List<Widget> _pages = <Widget>[
    _PlaceholderPage(label: 'Feed'), // 0: Feed（#10 で実装）
    MapScreen(), // 1: Map
    SizedBox.shrink(), // 2: 投稿（ダイアログのため未使用）
    _PlaceholderPage(label: 'Event'), // 3: Event（#15 で実装）
  ];

  void _onTabTapped(int index) {
    // 投稿タブは画面遷移せず、その場で投稿ダイアログを開く。
    if (index == _postIndex) {
      showDialog<void>(
        context: context,
        builder: (context) => const PostAddDialog(pos: _defaultPostLocation),
      );
      return;
    }

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
            icon: Icon(Icons.add_box_outlined),
            label: '投稿',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.event_outlined),
            label: 'Event',
          ),
        ],
      ),
    );
  }
}

/// 後続 Issue で実装予定のタブ用の最小プレースホルダ。
class _PlaceholderPage extends StatelessWidget {
  const _PlaceholderPage({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(label)),
      body: Center(child: Text('$label（準備中）')),
    );
  }
}
