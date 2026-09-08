import 'package:afterglow_app/models/contest.dart';
import 'package:afterglow_app/pages/contest_detail_page.dart';
import 'package:afterglow_app/services/contest_service.dart';
import 'package:afterglow_app/widgets/contest_edit_dialog.dart';
import 'package:afterglow_app/widgets/event_schedule_text.dart';
import 'package:flutter/material.dart';

class ContestListPage extends StatelessWidget {
  const ContestListPage({super.key, this.contestService});

  final ContestService? contestService;

  @override
  Widget build(BuildContext context) {
    final service = contestService ?? ContestService();

    return Scaffold(
      appBar: AppBar(title: const Text('Contest')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => showDialog<bool>(
          context: context,
          builder: (_) => ContestEditDialog(contestService: service),
        ),
        tooltip: 'コンテストを作成',
        child: const Icon(Icons.add),
      ),
      body: StreamBuilder<List<Contest>>(
        stream: service.getContests(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final contests = snapshot.data ?? const <Contest>[];
          if (contests.isEmpty) {
            return const Center(child: Text('まだコンテストがありません'));
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: contests.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) =>
                _ContestTile(contest: contests[index]),
          );
        },
      ),
    );
  }
}

class _ContestTile extends StatelessWidget {
  const _ContestTile({required this.contest});

  final Contest contest;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.emoji_events_outlined),
      title: Text(contest.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        '${_phaseLabel(contest.phase)} / エントリー締切 ${EventScheduleText.formatDateTime(contest.entryDeadline)}',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ContestDetailPage(contestId: contest.id),
        ),
      ),
    );
  }
}

String _phaseLabel(ContestPhase phase) {
  switch (phase) {
    case ContestPhase.entry:
      return 'エントリー受付中';
    case ContestPhase.voting:
      return '投票受付中';
    case ContestPhase.ended:
      return '終了';
  }
}
