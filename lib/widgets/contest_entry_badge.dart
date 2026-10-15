import 'dart:async';

import 'package:afterglow_app/models/contest.dart';
import 'package:afterglow_app/services/contest_service.dart';
import 'package:flutter/material.dart';

/// 一覧・詳細で共通の応募表示。表示中に投票締切を迎えても更新する。
class ContestEntryBadge extends StatefulWidget {
  const ContestEntryBadge({
    super.key,
    required this.contestId,
    required this.voteCount,
    this.contestService,
  });

  final String contestId;
  final int voteCount;
  final ContestService? contestService;

  @override
  State<ContestEntryBadge> createState() => _ContestEntryBadgeState();
}

class _ContestEntryBadgeState extends State<ContestEntryBadge> {
  StreamSubscription<Contest?>? _subscription;
  Timer? _deadlineTimer;
  Contest? _contest;

  @override
  void initState() {
    super.initState();
    _subscribe();
  }

  @override
  void didUpdateWidget(ContestEntryBadge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.contestId != widget.contestId ||
        oldWidget.contestService != widget.contestService) {
      _subscription?.cancel();
      _deadlineTimer?.cancel();
      _contest = null;
      _subscribe();
    }
  }

  void _subscribe() {
    _subscription = (widget.contestService ?? ContestService())
        .watchContest(widget.contestId)
        .listen(
          _updateContest,
          onError: (Object error) => _updateContest(null),
        );
  }

  void _updateContest(Contest? contest) {
    if (!mounted) return;
    _deadlineTimer?.cancel();
    setState(() => _contest = contest);
    if (contest != null) {
      final remaining = contest.votingDeadline.difference(DateTime.now());
      if (remaining > Duration.zero) {
        _deadlineTimer = Timer(remaining, () {
          if (mounted) setState(() {});
        });
      }
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _deadlineTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final contest = _contest;
    final title = contest == null || contest.title.isEmpty
        ? 'コンテスト'
        : contest.title;
    final status = contest == null || contest.phase == ContestPhase.ended
        ? '応募作品'
        : '参加中';
    return Chip(
      avatar: const Icon(Icons.emoji_events_outlined, size: 16),
      label: Text(
        '$title$status・${widget.voteCount}票',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      labelStyle: Theme.of(context).textTheme.labelSmall,
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}
