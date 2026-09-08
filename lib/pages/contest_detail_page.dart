import 'package:afterglow_app/models/contest.dart';
import 'package:afterglow_app/models/post.dart';
import 'package:afterglow_app/pages/post_detail_page.dart';
import 'package:afterglow_app/services/auth_service.dart';
import 'package:afterglow_app/services/contest_service.dart';
import 'package:afterglow_app/services/user_service.dart';
import 'package:afterglow_app/widgets/comment_section.dart';
import 'package:afterglow_app/widgets/contest_edit_dialog.dart';
import 'package:afterglow_app/widgets/event_schedule_text.dart';
import 'package:afterglow_app/widgets/post_card.dart';
import 'package:afterglow_app/widgets/reaction_bar.dart';
import 'package:flutter/material.dart';

class ContestDetailPage extends StatelessWidget {
  const ContestDetailPage({super.key, required this.contestId});

  final String contestId;

  @override
  Widget build(BuildContext context) {
    final contestService = ContestService();
    final userService = UserService();
    final currentUid = AuthService().currentUserId;

    return StreamBuilder<Contest?>(
      stream: contestService.watchContest(contestId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final contest = snapshot.data;
        if (contest == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: Text('コンテストが見つかりませんでした')),
          );
        }

        return FutureBuilder<bool>(
          future: _canManageContest(userService, contest, currentUid),
          builder: (context, permissionSnapshot) {
            final canManage = permissionSnapshot.data ?? false;
            return Scaffold(
              appBar: AppBar(
                title: Text(contest.title),
                actions: [
                  if (canManage)
                    IconButton(
                      icon: const Icon(Icons.edit),
                      tooltip: 'コンテストを編集',
                      onPressed: () => showDialog<bool>(
                        context: context,
                        builder: (_) => ContestEditDialog(contest: contest),
                      ),
                    ),
                ],
              ),
              body: _ContestBody(
                contest: contest,
                currentUid: currentUid,
                contestService: contestService,
              ),
            );
          },
        );
      },
    );
  }

  Future<bool> _canManageContest(
    UserService userService,
    Contest contest,
    String? uid,
  ) async {
    if (uid == null) {
      return false;
    }
    if (contest.creatorId == uid) {
      return true;
    }
    final user = await userService.getUser(uid);
    return user?.isAdmin == true;
  }
}

class _ContestBody extends StatelessWidget {
  const _ContestBody({
    required this.contest,
    required this.currentUid,
    required this.contestService,
  });

  final Contest contest;
  final String? currentUid;
  final ContestService contestService;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(contest.title, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        Chip(
          avatar: const Icon(Icons.flag_outlined, size: 16),
          label: Text(_phaseLabel(contest.phase)),
          visualDensity: VisualDensity.compact,
        ),
        if (contest.description.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(contest.description),
        ],
        const SizedBox(height: 16),
        _InfoRow(
          icon: Icons.login_outlined,
          text:
              'エントリー締切: ${EventScheduleText.formatDateTime(contest.entryDeadline)}',
        ),
        const SizedBox(height: 8),
        _InfoRow(
          icon: Icons.how_to_vote_outlined,
          text:
              '投票締切: ${EventScheduleText.formatDateTime(contest.votingDeadline)}',
        ),
        const SizedBox(height: 24),
        Text('エントリー', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        _EntryList(
          contest: contest,
          currentUid: currentUid,
          contestService: contestService,
        ),
      ],
    );
  }
}

class _EntryList extends StatelessWidget {
  const _EntryList({
    required this.contest,
    required this.currentUid,
    required this.contestService,
  });

  final Contest contest;
  final String? currentUid;
  final ContestService contestService;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Post>>(
      stream: contestService.getEntries(contest.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final entries = snapshot.data ?? const <Post>[];
        if (entries.isEmpty) {
          return const Text('まだエントリーがありません');
        }

        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: entries.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, index) => _EntryTile(
            contest: contest,
            post: entries[index],
            currentUid: currentUid,
            contestService: contestService,
          ),
        );
      },
    );
  }
}

class _EntryTile extends StatelessWidget {
  const _EntryTile({
    required this.contest,
    required this.post,
    required this.currentUid,
    required this.contestService,
  });

  final Contest contest;
  final Post post;
  final String? currentUid;
  final ContestService contestService;

  void _openDetail(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => PostDetailPage(
          post,
          reactionBar: ReactionBar(post: post),
          commentSection: CommentSection(post: post),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        PostCard(post, onTap: () => _openDetail(context)),
        if (contest.phase == ContestPhase.voting && currentUid != null)
          Padding(
            padding: const EdgeInsets.only(left: 12, right: 12, bottom: 8),
            child: _VoteButton(
              contest: contest,
              post: post,
              uid: currentUid!,
              contestService: contestService,
            ),
          ),
      ],
    );
  }
}

class _VoteButton extends StatefulWidget {
  const _VoteButton({
    required this.contest,
    required this.post,
    required this.uid,
    required this.contestService,
  });

  final Contest contest;
  final Post post;
  final String uid;
  final ContestService contestService;

  @override
  State<_VoteButton> createState() => _VoteButtonState();
}

class _VoteButtonState extends State<_VoteButton> {
  bool _isSubmitting = false;

  Future<void> _vote() async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _isSubmitting = true);
    try {
      await widget.contestService.voteFor(
        widget.contest.id,
        widget.post.id,
        widget.uid,
      );
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text('$error'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<String?>(
      stream: widget.contestService.watchUserVote(
        widget.contest.id,
        widget.uid,
      ),
      builder: (context, snapshot) {
        final voted = snapshot.data == widget.post.id;
        return SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: voted || _isSubmitting ? null : _vote,
            icon: Icon(voted ? Icons.check_circle : Icons.how_to_vote_outlined),
            label: Text(voted ? '投票済み' : 'この投稿に投票'),
          ),
        );
      },
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: Colors.grey.shade600),
        const SizedBox(width: 8),
        Expanded(child: Text(text)),
      ],
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
