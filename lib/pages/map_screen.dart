import 'package:afterglow_app/models/post.dart';
import 'package:afterglow_app/services/post_service.dart';
import 'package:afterglow_app/widgets/post_add_dialog.dart';
import 'package:afterglow_app/widgets/post_widget.dart';
import 'package:cached_network_image/cached_network_image.dart';
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

  final PostService _postService = PostService();
  late final Stream<List<Post>> _postsStream = _postService.getPosts();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Map')),
      body: StreamBuilder<List<Post>>(
        stream: _postsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final posts = snapshot.data ?? [];

          // 画像プリロード: Firestore データ到着後に裏でダウンロード開始
          for (final post in posts) {
            for (final url in post.imageUrls) {
              precacheImage(
                CachedNetworkImageProvider(url),
                context,
                onError: (_, __) {},
              );
            }
          }

          return FlutterMap(
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
