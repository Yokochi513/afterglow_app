import 'package:afterglow_app/widgets/post_location_confirm_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

/// 投稿位置を地図から選び直すフルスクリーンページ（Issue #37）。
///
/// [initialPosition] を中心に地図を表示し、現在の位置に赤ピンを出す。
/// 地図タップで選択マーカーを置き（再タップで取り直し）、確認バーの
/// 確定で選んだ [LatLng] を `Navigator.pop` の戻り値として返す。
/// 何も確定せず戻った場合は null を返す。
class LocationPickerPage extends StatefulWidget {
  const LocationPickerPage({super.key, required this.initialPosition});

  /// 現在の投稿位置。地図の初期中心と既存位置マーカーに使う。
  final LatLng initialPosition;

  @override
  State<LocationPickerPage> createState() => _LocationPickerPageState();
}

class _LocationPickerPageState extends State<LocationPickerPage> {
  /// 現在の位置を確認しつつ微調整できるよう、街区が見えるズームで開く。
  static const double _initialZoom = 16.0;

  /// 地図タップで選択中の新しい位置。null の間は選択マーカーも確認バーも
  /// 出さない。再タップで置き換わる（＝位置の取り直し）。
  LatLng? _selectedPos;

  /// 選択中の位置を確定し、呼び出し元へ返す。
  void _confirmSelection() {
    final pos = _selectedPos;
    if (pos == null) return;
    Navigator.of(context).pop(pos);
  }

  /// 位置の選択をやめ、選択マーカーと確認バーを消す。
  void _cancelSelection() {
    setState(() => _selectedPos = null);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('位置を選び直す')),
      // 位置選択中だけ出す確認バー（map_screen と同じ配置）。
      bottomSheet: _selectedPos == null
          ? null
          : PostLocationConfirmBar(
              message: 'この場所に変更しますか？',
              confirmLabel: 'この場所にする',
              confirmIcon: Icons.check,
              onConfirm: _confirmSelection,
              onCancel: _cancelSelection,
            ),
      body: FlutterMap(
        options: MapOptions(
          initialCenter: widget.initialPosition,
          initialZoom: _initialZoom,
          // Issue #57: 意図せず地図の向きが変わって使いにくいため、回転ジェスチャーだけ無効化する。
          interactionOptions: const InteractionOptions(
            flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
          ),
          onTap: (tapPosition, latLng) {
            setState(() => _selectedPos = latLng);
          },
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.afterglow_app.app',
          ),
          // 現在の投稿位置（赤ピン）。どこから動かすのかの目印として出す。
          MarkerLayer(
            markers: [
              Marker(
                point: widget.initialPosition,
                width: 48,
                height: 48,
                child: const IgnorePointer(
                  child: Icon(Icons.location_on, color: Colors.red, size: 40),
                ),
              ),
            ],
          ),
          // 選択中の新しい位置。投稿ピン（赤）と見分けられるようテーマ色にし、
          // 最前面に描画する（map_screen の選択マーカーと同じスタイル）。
          if (_selectedPos != null)
            MarkerLayer(
              markers: [
                Marker(
                  point: _selectedPos!,
                  width: 48,
                  height: 48,
                  child: IgnorePointer(
                    child: Icon(
                      Icons.add_location_alt,
                      color: Theme.of(context).colorScheme.primary,
                      size: 40,
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
