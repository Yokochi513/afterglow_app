import 'package:afterglow_app/models/post.dart';
import 'package:afterglow_app/services/auth_service.dart';
import 'package:afterglow_app/services/reaction_service.dart';
import 'package:flutter/material.dart';

/// いいね数 + トグルボタン（PS_05 / #13）。
///
/// 押下で自分のリアクションを追加/解除する。押下状態といいね数は
/// `posts/{postId}/reactions` の購読で即時反映される。
/// 未ログインでは操作できない（`reactions` ルールと整合。未承認ユーザーは
/// [AuthGate] がアプリ本体へ入れないため、ここには到達しない）。
///
/// [compact] を true にするとフィードのカード（[PostCard]）向けの小さい体裁になる。
class ReactionBar extends StatefulWidget {
  const ReactionBar({
    super.key,
    required this.post,
    this.compact = false,
    this.authService,
    this.reactionService,
  });

  final Post post;

  /// カード内に並べる小さい体裁にするか。
  final bool compact;

  /// テスト時に差し替え可能。null の場合はビルド時に既定インスタンスを生成する。
  final AuthService? authService;
  final ReactionService? reactionService;

  @override
  State<ReactionBar> createState() => _ReactionBarState();
}

class _ReactionBarState extends State<ReactionBar> {
  late final AuthService _authService = widget.authService ?? AuthService();
  late final ReactionService _reactionService =
      widget.reactionService ?? ReactionService();

  /// 連打で複数のトランザクションが競合しないようにするフラグ。
  bool _isToggling = false;

  Future<void> _toggle() async {
    final uid = _authService.currentUserId;
    if (uid == null || _isToggling) {
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    setState(() => _isToggling = true);

    try {
      await _reactionService.toggleReaction(widget.post.id, uid);
    } catch (_) {
      if (mounted) {
        messenger.showSnackBar(const SnackBar(content: Text('いいねに失敗しました')));
      }
    } finally {
      if (mounted) {
        setState(() => _isToggling = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = _authService.currentUserId;

    return StreamBuilder<bool>(
      // 未ログインなら購読せず、常に未リアクション表示にする。
      stream: uid == null
          ? const Stream<bool>.empty()
          : _reactionService.hasReacted(widget.post.id, uid),
      initialData: false,
      builder: (context, reactedSnapshot) {
        final hasReacted = reactedSnapshot.data ?? false;

        return StreamBuilder<int>(
          stream: _reactionService.getReactionCount(widget.post.id),
          // 購読が始まるまでは投稿の非正規化カウントを表示し、数字のちらつきを防ぐ。
          initialData: widget.post.likeCount,
          builder: (context, countSnapshot) {
            final count = countSnapshot.data ?? widget.post.likeCount;
            return widget.compact
                ? _buildCompact(hasReacted: hasReacted, count: count)
                : _buildFull(
                    hasReacted: hasReacted,
                    count: count,
                    enabled: uid != null,
                  );
          },
        );
      },
    );
  }

  /// 詳細画面向け。アイコンボタン + いいね数。
  Widget _buildFull({
    required bool hasReacted,
    required int count,
    required bool enabled,
  }) {
    return Row(
      children: [
        IconButton(
          onPressed: enabled && !_isToggling ? _toggle : null,
          icon: Icon(
            hasReacted ? Icons.favorite : Icons.favorite_border,
            color: hasReacted ? Colors.red : null,
          ),
          tooltip: hasReacted ? 'いいねを取り消す' : 'いいね',
        ),
        Text('$count', style: Theme.of(context).textTheme.bodyMedium),
      ],
    );
  }

  /// フィードのカード向け。行の高さを抑えた小さいボタン + いいね数。
  Widget _buildCompact({required bool hasReacted, required int count}) {
    final enabled = _authService.currentUserId != null;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: enabled && !_isToggling ? _toggle : null,
          icon: Icon(
            hasReacted ? Icons.favorite : Icons.favorite_border,
            size: 16,
            color: hasReacted ? Colors.red : null,
          ),
          tooltip: hasReacted ? 'いいねを取り消す' : 'いいね',
          padding: EdgeInsets.zero,
          visualDensity: VisualDensity.compact,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        ),
        const SizedBox(width: 4),
        Text('$count', style: Theme.of(context).textTheme.labelMedium),
      ],
    );
  }
}
