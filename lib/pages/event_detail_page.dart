import 'package:afterglow_app/models/app_user.dart';
import 'package:afterglow_app/models/event.dart';
import 'package:afterglow_app/pages/profile_page.dart';
import 'package:afterglow_app/services/auth_service.dart';
import 'package:afterglow_app/services/event_service.dart';
import 'package:afterglow_app/services/user_service.dart';
import 'package:afterglow_app/widgets/event_edit_dialog.dart';
import 'package:afterglow_app/widgets/event_schedule_text.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

/// イベント詳細画面（PS_06 / FR_05 / §5.7）。
///
/// イベント名・日時・集合場所（地図ミニプレビュー）・参加者一覧とその参加
/// コメントを表示し、参加表明をトグルできる。閲覧・参加は承認済みユーザー
/// 全員が行えるが、編集は主催者（`organizerId`）のみに限定する
/// （Firestore ルールでも担保・§7.2）。
class EventDetailPage extends StatelessWidget {
  const EventDetailPage({super.key, required this.eventId});

  final String eventId;

  @override
  Widget build(BuildContext context) {
    final eventService = EventService();
    final currentUid = AuthService().currentUserId;

    return StreamBuilder<Event?>(
      stream: eventService.watchEvent(eventId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final event = snapshot.data;
        if (event == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: Text('イベントが見つかりませんでした')),
          );
        }

        final isOrganizer = eventService.isOrganizedBy(event, currentUid);

        return Scaffold(
          appBar: AppBar(
            title: Text(event.title),
            actions: [
              if (isOrganizer)
                IconButton(
                  icon: const Icon(Icons.edit),
                  tooltip: 'イベントを編集',
                  onPressed: () => showDialog<bool>(
                    context: context,
                    builder: (_) => EventEditDialog(event: event),
                  ),
                ),
            ],
          ),
          body: _EventBody(event: event, currentUid: currentUid),
        );
      },
    );
  }
}

class _EventBody extends StatelessWidget {
  const _EventBody({required this.event, required this.currentUid});

  final Event event;

  /// ログイン中ユーザーの UID。未ログインなら null で参加導線を出さない。
  final String? currentUid;

  @override
  Widget build(BuildContext context) {
    final userService = UserService();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(event.title, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          StreamBuilder<AppUser?>(
            stream: userService.watchUser(event.organizerId),
            builder: (context, snapshot) {
              final username = snapshot.data?.username ?? '';
              return Text(
                '主催: ${username.isEmpty ? '名無しさん' : username}',
                style: Theme.of(context).textTheme.bodySmall,
              );
            },
          ),
          const SizedBox(height: 16),
          _InfoRow(
            icon: Icons.schedule,
            child: EventScheduleText(event: event),
          ),
          if (event.locationName.isNotEmpty) ...[
            const SizedBox(height: 8),
            _InfoRow(
              icon: Icons.place_outlined,
              child: Text(event.locationName),
            ),
          ],
          if (event.hasLocation) ...[
            const SizedBox(height: 12),
            _LocationPreview(event: event),
          ],
          if (event.description.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(event.description),
          ],
          const SizedBox(height: 24),
          if (currentUid != null)
            _ParticipationButton(event: event, uid: currentUid!),
          const SizedBox(height: 24),
          const Divider(height: 1),
          const SizedBox(height: 16),
          _ParticipantList(event: event),
        ],
      ),
    );
  }
}

/// アイコン付きの情報 1 行。
class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.child});

  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: Colors.grey.shade600),
        const SizedBox(width: 8),
        Expanded(child: child),
      ],
    );
  }
}

/// 集合場所の地図ミニプレビュー（§5.7）。
/// 位置を示すだけなので操作は受け付けない。
class _LocationPreview extends StatelessWidget {
  const _LocationPreview({required this.event});

  final Event event;

  @override
  Widget build(BuildContext context) {
    final point = LatLng(event.latitude!, event.longitude!);

    return SizedBox(
      height: 160,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: FlutterMap(
          options: MapOptions(
            initialCenter: point,
            initialZoom: 15,
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.none,
            ),
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.afterglow_app.app',
            ),
            MarkerLayer(
              markers: [
                Marker(
                  point: point,
                  width: 48,
                  height: 48,
                  child: const Icon(
                    Icons.location_on,
                    color: Colors.red,
                    size: 40,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 参加表明トグル（PS_06）。
/// 未参加なら参加コメント（任意）を尋ねてから `participants/{uid}` を作成し、
/// 参加済みなら確認のうえ削除する。
class _ParticipationButton extends StatefulWidget {
  const _ParticipationButton({required this.event, required this.uid});

  final Event event;
  final String uid;

  @override
  State<_ParticipationButton> createState() => _ParticipationButtonState();
}

class _ParticipationButtonState extends State<_ParticipationButton> {
  final EventService _eventService = EventService();

  /// 通信中は二重押下を防ぐ。
  bool _isSubmitting = false;

  /// 参加コメントを尋ねる。キャンセルなら null（＝参加もしない）。
  /// 空文字のまま決定した場合はコメント無しの参加として空文字を返す。
  Future<String?> _askComment() {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('イベントに参加'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 2,
          decoration: const InputDecoration(
            labelText: '参加コメント（任意）',
            hintText: '例: 現地で合流します',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('参加する'),
          ),
        ],
      ),
    ).whenComplete(controller.dispose);
  }

  Future<bool> _confirmCancel() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('参加を取り消し'),
        content: const Text('このイベントへの参加を取り消しますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('やめる'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('取り消す'),
          ),
        ],
      ),
    );
    return result == true;
  }

  Future<void> _toggle(bool isParticipating) async {
    String? comment;
    if (isParticipating) {
      if (!await _confirmCancel()) {
        return;
      }
    } else {
      comment = await _askComment();
      if (comment == null) {
        return;
      }
    }

    if (!mounted) {
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    setState(() => _isSubmitting = true);

    try {
      await _eventService.toggleParticipation(
        widget.event.id,
        widget.uid,
        // コメント未入力なら null で保存し、空文字を残さない。
        (comment != null && comment.isEmpty) ? null : comment,
      );
    } catch (_) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(isParticipating ? '参加の取り消しに失敗しました' : '参加表明に失敗しました'),
          backgroundColor: Colors.red,
        ),
      );
    }

    if (mounted) {
      setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<bool>(
      stream: _eventService.watchIsParticipating(widget.event.id, widget.uid),
      builder: (context, snapshot) {
        final isParticipating = snapshot.data ?? false;

        return SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _isSubmitting ? null : () => _toggle(isParticipating),
            icon: Icon(
              isParticipating ? Icons.check_circle : Icons.how_to_reg_outlined,
            ),
            label: Text(isParticipating ? '参加中（タップで取り消し）' : 'このイベントに参加する'),
            style: isParticipating
                ? FilledButton.styleFrom(backgroundColor: Colors.grey.shade600)
                : null,
          ),
        );
      },
    );
  }
}

/// 参加者一覧（§5.7）。各参加者のアイコン・名前と参加コメントを表示する。
class _ParticipantList extends StatelessWidget {
  const _ParticipantList({required this.event});

  final Event event;

  @override
  Widget build(BuildContext context) {
    final eventService = EventService();

    return StreamBuilder<List<EventParticipant>>(
      stream: eventService.getParticipants(event.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final participants = snapshot.data ?? const <EventParticipant>[];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '参加者（${participants.length}人）',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            if (participants.isEmpty)
              Text(
                'まだ参加者はいません',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: participants.length,
                separatorBuilder: (_, _) => const Divider(height: 8),
                itemBuilder: (context, index) =>
                    _ParticipantTile(participant: participants[index]),
              ),
          ],
        );
      },
    );
  }
}

/// 参加者一覧の 1 行。タップでプロフィールへ遷移する。
class _ParticipantTile extends StatelessWidget {
  const _ParticipantTile({required this.participant});

  final EventParticipant participant;

  @override
  Widget build(BuildContext context) {
    final comment = participant.comment;

    return StreamBuilder<AppUser?>(
      stream: UserService().watchUser(participant.userId),
      builder: (context, snapshot) {
        final user = snapshot.data;
        final hasImage = (user?.profileImageUrl ?? '').isNotEmpty;
        final username = (user?.username ?? '').isNotEmpty
            ? user!.username
            : '不明なユーザー';

        return ListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          leading: CircleAvatar(
            radius: 16,
            backgroundColor: Colors.grey.shade200,
            backgroundImage: hasImage
                ? CachedNetworkImageProvider(user!.profileImageUrl!)
                : null,
            child: hasImage
                ? null
                : const Icon(Icons.person, size: 18, color: Colors.grey),
          ),
          title: Text(username, overflow: TextOverflow.ellipsis),
          subtitle: comment == null || comment.isEmpty ? null : Text(comment),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => ProfilePage(userId: participant.userId),
            ),
          ),
        );
      },
    );
  }
}
