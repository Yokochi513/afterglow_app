import 'package:afterglow_app/models/event.dart';
import 'package:afterglow_app/services/auth_service.dart';
import 'package:afterglow_app/services/event_service.dart';
import 'package:afterglow_app/widgets/event_schedule_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

/// イベントの作成・編集ダイアログ（PS_06）。
///
/// [event] を渡すと編集、省略すると新規作成として振る舞う。編集できるのは
/// 主催者のみで、呼び出し側がこのダイアログを開く導線を出し分ける
/// （Firestore ルールでも担保・§7.2）。保存に成功すると `true` を返して閉じる。
class EventEditDialog extends StatefulWidget {
  const EventEditDialog({super.key, this.event});

  /// 編集対象のイベント。null なら新規作成。
  final Event? event;

  @override
  State<EventEditDialog> createState() => _EventEditDialogState();
}

class _EventEditDialogState extends State<EventEditDialog> {
  /// 集合場所ピッカーの既定位置（[MapScreen] の既定位置に揃える）。
  static const LatLng _defaultLocation = LatLng(34.669478, 133.951104);

  final EventService _eventService = EventService();
  final AuthService _authService = AuthService();

  late final TextEditingController _titleController = TextEditingController(
    text: widget.event?.title ?? '',
  );
  late final TextEditingController _descriptionController =
      TextEditingController(text: widget.event?.description ?? '');
  late final TextEditingController _locationNameController =
      TextEditingController(text: widget.event?.locationName ?? '');

  /// 開始日時。新規作成時は「翌日の 10:00」を初期値にする。
  late DateTime _startAt = widget.event?.startAt ?? _defaultStartAt();

  /// 終了日時。未設定なら null。
  late DateTime? _endAt = widget.event?.endAt;

  /// 地図で選んだ集合場所。未選択なら null で、ミニプレビューは表示されない。
  late LatLng? _pickedLocation = widget.event?.hasLocation ?? false
      ? LatLng(widget.event!.latitude!, widget.event!.longitude!)
      : null;

  bool _isSaving = false;

  bool get _isEditing => widget.event != null;

  static DateTime _defaultStartAt() {
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    return DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 10);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationNameController.dispose();
    super.dispose();
  }

  void _showError(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  /// 日付 → 時刻の順に選ばせて日時を組み立てる。どちらかで取り消したら null。
  Future<DateTime?> _pickDateTime(DateTime initial) async {
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(initial.year - 1),
      lastDate: DateTime(initial.year + 5),
    );
    if (date == null || !mounted) {
      return null;
    }

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null) {
      return null;
    }

    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  Future<void> _editStartAt() async {
    final picked = await _pickDateTime(_startAt);
    if (picked == null) {
      return;
    }
    setState(() {
      _startAt = picked;
      // 開始が終了を追い越したら終了日時は無効になるため取り消す。
      if (_endAt != null && !_endAt!.isAfter(picked)) {
        _endAt = null;
      }
    });
  }

  Future<void> _editEndAt() async {
    final picked = await _pickDateTime(_endAt ?? _startAt);
    if (picked == null) {
      return;
    }
    if (!picked.isAfter(_startAt)) {
      _showError('終了日時は開始日時より後にしてください');
      return;
    }
    setState(() => _endAt = picked);
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      _showError('イベント名を入力してください');
      return;
    }

    final uid = _authService.currentUserId;
    if (uid == null) {
      _showError('ログイン情報が取得できませんでした');
      return;
    }

    setState(() => _isSaving = true);

    final now = DateTime.now();
    final event = Event(
      id: widget.event?.id ?? '',
      // 編集時は主催者を引き継ぐ（サービス側でも書き換えない）。
      organizerId: widget.event?.organizerId ?? uid,
      title: title,
      description: _descriptionController.text.trim(),
      locationName: _locationNameController.text.trim(),
      latitude: _pickedLocation?.latitude,
      longitude: _pickedLocation?.longitude,
      startAt: _startAt,
      endAt: _endAt,
      createdAt: widget.event?.createdAt ?? now,
      updatedAt: now,
    );

    final succeeded = _isEditing
        ? await _eventService.updateEvent(event)
        : await _eventService.createEvent(event);

    if (!mounted) {
      return;
    }

    if (!succeeded) {
      setState(() => _isSaving = false);
      _showError(_isEditing ? 'イベントの更新に失敗しました' : 'イベントの作成に失敗しました');
      return;
    }

    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEditing ? 'イベントを編集' : 'イベントを作成'),
      content: SizedBox(
        width: 360,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _titleController,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'イベント名',
                  hintText: '例: 夏の撮影会',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _descriptionController,
                maxLines: 3,
                decoration: const InputDecoration(labelText: '詳細（任意）'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _locationNameController,
                decoration: const InputDecoration(
                  labelText: '集合場所（任意）',
                  hintText: '例: 岡山駅 東口',
                ),
              ),
              const SizedBox(height: 8),
              _buildDateTimeRow(
                label: '開始日時',
                value: EventScheduleText.formatDateTime(_startAt),
                onPressed: _isSaving ? null : _editStartAt,
              ),
              _buildDateTimeRow(
                label: '終了日時',
                value: _endAt == null
                    ? '未設定'
                    : EventScheduleText.formatDateTime(_endAt!),
                onPressed: _isSaving ? null : _editEndAt,
                onClear: _endAt == null || _isSaving
                    ? null
                    : () => setState(() => _endAt = null),
              ),
              const SizedBox(height: 12),
              _buildLocationPicker(),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(false),
          child: const Text('キャンセル'),
        ),
        TextButton(
          onPressed: _isSaving ? null : _save,
          child: _isSaving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(_isEditing ? '保存' : '作成'),
        ),
      ],
    );
  }

  Widget _buildDateTimeRow({
    required String label,
    required String value,
    required VoidCallback? onPressed,
    VoidCallback? onClear,
  }) {
    return Row(
      children: [
        Expanded(child: Text(label)),
        TextButton(onPressed: onPressed, child: Text(value)),
        if (onClear != null)
          IconButton(
            icon: const Icon(Icons.clear, size: 18),
            tooltip: '終了日時を未設定にする',
            onPressed: onClear,
          ),
      ],
    );
  }

  /// 集合場所を地図から選ぶ。タップした位置がピンになる（§5.7 の地図連携）。
  Widget _buildLocationPicker() {
    final picked = _pickedLocation;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(child: Text('集合場所を地図で選択（任意）')),
            if (picked != null)
              IconButton(
                icon: const Icon(Icons.clear, size: 18),
                tooltip: '集合場所の位置を消す',
                onPressed: _isSaving
                    ? null
                    : () => setState(() => _pickedLocation = null),
              ),
          ],
        ),
        const SizedBox(height: 4),
        SizedBox(
          height: 160,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: FlutterMap(
              options: MapOptions(
                initialCenter: picked ?? _defaultLocation,
                initialZoom: 14,
                onTap: _isSaving
                    ? null
                    : (_, latLng) => setState(() => _pickedLocation = latLng),
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.afterglow_app.app',
                ),
                if (picked != null)
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: picked,
                        width: 48,
                        height: 48,
                        child: const IgnorePointer(
                          child: Icon(
                            Icons.location_on,
                            color: Colors.red,
                            size: 40,
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
