import 'package:afterglow_app/widgets/post_add_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  static const LatLng _defaultLocation = LatLng(34.669478, 133.951104);

  static const double _defaultZoom = 14.0;

  // final MapController _mapController = MapController();

  LatLng _currentPos = _defaultLocation;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Map')),
      body: FlutterMap(
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
            userAgentPackageName: 'com.afterglow_app.app', // 推奨
          ),
        ],
      ),
    );
  }
}
