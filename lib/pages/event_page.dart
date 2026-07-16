import 'package:afterglow_app/models/app_user.dart';
import 'package:afterglow_app/models/event.dart';
import 'package:afterglow_app/pages/event_detail_page.dart';
import 'package:afterglow_app/services/event_service.dart';
import 'package:afterglow_app/services/user_service.dart';
import 'package:afterglow_app/widgets/event_edit_dialog.dart';
import 'package:afterglow_app/widgets/event_schedule_text.dart';
import 'package:flutter/material.dart';

/// イベント一覧画面（PS_06 / FR_05 / §5.7）。
///
/// **表示範囲は「全体」**：承認済みユーザー全員が閲覧でき、開催日（`startAt`）
/// 昇順に並べる。作成は誰でも行え、更新は主催者のみ（[EventDetailPage]）。
class EventPage extends StatelessWidget {
  const EventPage({super.key});

  @override
  Widget build(BuildContext context) {
    final eventService = EventService();

    return Scaffold(
      appBar: AppBar(title: const Text('イベント')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => showDialog<bool>(
          context: context,
          builder: (_) => const EventEditDialog(),
        ),
        tooltip: 'イベントを作成',
        child: const Icon(Icons.add),
      ),
      body: StreamBuilder<List<Event>>(
        stream: eventService.getEvents(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final events = snapshot.data ?? [];
          if (events.isEmpty) {
            return const Center(child: Text('まだイベントがありません'));
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: events.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) => _EventTile(event: events[index]),
          );
        },
      ),
    );
  }
}

/// 一覧の 1 行。開催日時・イベント名・主催者名・集合場所を表示する。
class _EventTile extends StatelessWidget {
  const _EventTile({required this.event});

  final Event event;

  @override
  Widget build(BuildContext context) {
    final userService = UserService();

    return ListTile(
      leading: const Icon(Icons.event_outlined),
      title: Text(event.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(EventScheduleText.formatDateTime(event.startAt)),
          StreamBuilder<AppUser?>(
            stream: userService.watchUser(event.organizerId),
            builder: (context, snapshot) {
              final username = snapshot.data?.username ?? '';
              final organizer = username.isEmpty ? '名無しさん' : username;
              final place = event.locationName.isEmpty
                  ? ''
                  : '・${event.locationName}';
              return Text(
                '主催: $organizer$place',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              );
            },
          ),
        ],
      ),
      isThreeLine: true,
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => EventDetailPage(eventId: event.id),
        ),
      ),
    );
  }
}
