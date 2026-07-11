import 'package:afterglow_app/models/post.dart';
import 'package:afterglow_app/pages/profile_page.dart';
import 'package:afterglow_app/pages/release_notes_page.dart';
import 'package:afterglow_app/services/location_service.dart';
import 'package:afterglow_app/services/post_service.dart';
import 'package:afterglow_app/services/release_note_service.dart';
import 'package:afterglow_app/widgets/post_add_dialog.dart';
import 'package:afterglow_app/widgets/post_widget.dart';
import 'package:afterglow_app/widgets/release_note_dialog.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key, LocationService? locationService})
    : _locationService = locationService;

  /// テストからモックを注入するための位置情報サービス（省略時は既定実装）。
  final LocationService? _locationService;

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  static const LatLng _defaultLocation = LatLng(34.669478, 133.951104);

  static const double _defaultZoom = 14.0;

  /// 現在地へ移動したときのズームレベル。
  static const double _locatedZoom = 16.0;

  final MapController _mapController = MapController();

  LatLng _currentPos = _defaultLocation;

  final PostService _postService = PostService();
  late final Stream<List<Post>> _postsStream = _postService.getPosts();

  final ReleaseNoteService _releaseNoteService = ReleaseNoteService();

  late final LocationService _locationService =
      widget._locationService ?? LocationService();

  /// 現在地取得中は true。ボタンの二重押下を防ぎ、スピナーを表示する。
  bool _isLocating = false;

  // 既にプリキャッシュ済みの画像URL（再ビルドでの重複プリキャッシュを防ぐ）
  final Set<String> _precachedUrls = {};

  @override
  void initState() {
    super.initState();
    // 更新後の初回起動なら、最初のフレーム描画後にリリースお知らせを自動表示する。
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeAnnounce());
  }

  /// 未読のバージョンがあればリリースお知らせダイアログを表示し、既読として記録する。
  /// アプリの主要動作ではないため、読み込みに失敗しても無視する。
  Future<void> _maybeAnnounce() async {
    try {
      if (!await _releaseNoteService.shouldAnnounce()) return;
      final note = await _releaseNoteService.announcementNote();
      if (note != null && mounted) {
        await ReleaseNoteDialog.show(context, note);
      }
      await _releaseNoteService.markAnnounced();
    } catch (_) {
      // お知らせの表示失敗はアプリ利用を妨げないため握りつぶす
    }
  }

  void _openReleaseNotes() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const ReleaseNotesPage()));
  }

  /// 現在地を取得し、成功したら地図をそこへ移動する。
  /// 失敗（サービス無効・拒否・タイムアウト等）してもクラッシュせず、
  /// SnackBar で理由を案内する（永久拒否時は設定を開く導線を出す）。
  Future<void> _moveToCurrentLocation() async {
    if (_isLocating) return;
    setState(() => _isLocating = true);

    final result = await _locationService.getCurrentLocation();

    if (!mounted) return;
    setState(() => _isLocating = false);

    if (result.isSuccess) {
      final position = result.position!;
      final target = LatLng(position.latitude, position.longitude);
      setState(() => _currentPos = target);
      _mapController.move(target, _locatedZoom);
      return;
    }

    final errorType = result.errorType!;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(LocationService.messageFor(errorType)),
        action: errorType == LocationErrorType.permissionDeniedForever
            ? SnackBarAction(
                label: '設定を開く',
                onPressed: _locationService.openAppSettings,
              )
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Map'),
        actions: [
          IconButton(
            icon: const Icon(Icons.campaign_outlined),
            tooltip: 'お知らせ',
            onPressed: _openReleaseNotes,
          ),
          IconButton(
            icon: const Icon(Icons.account_circle),
            tooltip: 'プロフィール',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const ProfilePage()),
              );
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: '現在地へ移動',
        onPressed: _isLocating ? null : _moveToCurrentLocation,
        child: _isLocating
            ? const SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.my_location),
      ),
      body: StreamBuilder<List<Post>>(
        stream: _postsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final posts = snapshot.data ?? [];

          // 画像プリロード: Firestore データ到着後に裏でダウンロード開始
          // （URLごとに一度だけ実行し、再ビルドでの重複ダウンロードを防ぐ）
          for (final post in posts) {
            for (final url in post.imageUrls) {
              if (_precachedUrls.add(url)) {
                precacheImage(
                  CachedNetworkImageProvider(url),
                  context,
                  onError: (_, _) {},
                );
              }
            }
          }

          return FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _currentPos,
              initialZoom: _defaultZoom,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all,
              ),
              onTap: (tapPosition, latLng) {
                setState(() {
                  _currentPos = latLng;
                });
                showDialog<void>(
                  context: context,
                  builder: (context) => PostAddDialog(pos: latLng),
                );
              },
            ),
            children: [
              TileLayer(
                urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
                userAgentPackageName: 'com.afterglow_app.app',
              ),
              MarkerLayer(
                markers: posts.map((post) {
                  return Marker(
                    point: LatLng(post.latitude, post.longitude),
                    width: 48,
                    height: 48,
                    child: GestureDetector(
                      onTap: () {
                        showDialog<void>(
                          context: context,
                          builder: (context) => PostCardView(post),
                        );
                      },
                      child: const Icon(
                        Icons.location_on,
                        color: Colors.red,
                        size: 40,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          );
        },
      ),
    );
  }
}
