import 'package:afterglow_app/services/geocoding_service.dart';
import 'package:flutter/material.dart';

/// マップ画面用の場所検索バー。地名・施設名で検索し、候補一覧から
/// 選んだ場所を [onPlaceSelected] で親（地図）へ通知する。
///
/// Nominatim の利用ポリシーに合わせ、検索は入力確定（Enter・検索ボタン）
/// 時のみ実行する（1 文字ごとのオートコンプリートはしない）。
class MapSearchBar extends StatefulWidget {
  const MapSearchBar({
    super.key,
    required this.onPlaceSelected,
    GeocodingService? geocodingService,
  }) : _geocodingService = geocodingService;

  /// 候補が選択されたときに呼ばれる。地図の移動は親が行う。
  final ValueChanged<PlaceSearchResult> onPlaceSelected;

  /// テストからモックを注入するための検索サービス（省略時は既定実装）。
  final GeocodingService? _geocodingService;

  @override
  State<MapSearchBar> createState() => _MapSearchBarState();
}

class _MapSearchBarState extends State<MapSearchBar> {
  late final GeocodingService _geocodingService =
      widget._geocodingService ?? GeocodingService();

  final TextEditingController _controller = TextEditingController();

  /// 検索結果の候補。null は「未検索（一覧を出さない）」、
  /// 空リストは「検索したが該当なし」を表す。
  List<PlaceSearchResult>? _places;

  /// 検索に失敗（ネットワーク断など）したら true。
  bool _hasError = false;

  bool _isSearching = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final query = _controller.text.trim();
    if (query.isEmpty || _isSearching) return;
    setState(() {
      _isSearching = true;
      _hasError = false;
      _places = null;
    });

    final response = await _geocodingService.search(query);

    if (!mounted) return;
    setState(() {
      _isSearching = false;
      _hasError = !response.isSuccess;
      _places = response.isSuccess ? response.places : null;
    });
  }

  void _selectPlace(PlaceSearchResult place) {
    setState(() => _places = null);
    FocusScope.of(context).unfocus();
    widget.onPlaceSelected(place);
  }

  /// 入力・候補・エラーをすべて消して未検索状態へ戻す。
  void _clear() {
    _controller.clear();
    setState(() {
      _places = null;
      _hasError = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final places = _places;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          elevation: 4,
          borderRadius: BorderRadius.circular(28),
          child: TextField(
            controller: _controller,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _search(),
            decoration: InputDecoration(
              hintText: '場所を検索',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(28),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: Theme.of(context).colorScheme.surface,
              prefixIcon: _isSearching
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : IconButton(
                      icon: const Icon(Icons.search),
                      tooltip: '検索',
                      onPressed: _search,
                    ),
              suffixIcon: IconButton(
                icon: const Icon(Icons.close),
                tooltip: 'クリア',
                onPressed: _clear,
              ),
            ),
          ),
        ),
        if (_hasError || places != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Material(
              elevation: 4,
              borderRadius: BorderRadius.circular(12),
              clipBehavior: Clip.antiAlias,
              child: _buildResultPanel(places),
            ),
          ),
      ],
    );
  }

  /// 検索バー直下の結果パネル。エラー・該当なし・候補一覧を出し分ける。
  Widget _buildResultPanel(List<PlaceSearchResult>? places) {
    if (_hasError) {
      return const ListTile(
        leading: Icon(Icons.error_outline),
        title: Text('検索に失敗しました。時間をおいて再度お試しください。'),
      );
    }
    if (places == null || places.isEmpty) {
      return const ListTile(
        leading: Icon(Icons.search_off),
        title: Text('該当する場所が見つかりませんでした。'),
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final place in places)
          ListTile(
            leading: const Icon(Icons.place_outlined),
            title: Text(
              place.displayName,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            onTap: () => _selectPlace(place),
          ),
      ],
    );
  }
}
