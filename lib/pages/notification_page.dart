import 'package:afterglow_app/models/app_user.dart';
import 'package:afterglow_app/models/notification.dart';
import 'package:afterglow_app/pages/event_detail_page.dart';
import 'package:afterglow_app/pages/post_detail_page.dart';
import 'package:afterglow_app/services/auth_service.dart';
import 'package:afterglow_app/services/notification_service.dart';
import 'package:afterglow_app/services/post_service.dart';
import 'package:afterglow_app/services/push_notification_service.dart';
import 'package:afterglow_app/services/user_service.dart';
import 'package:flutter/material.dart';

/// 通知一覧ページ（PS_07 / §6.6）。
///
/// 自分宛ての通知（リアクション・コメント・イベント更新）を新しい順に並べ、
/// 未読は背景色とドットで区別する。タップで既読にし、対象の投稿詳細または
/// イベント詳細へ遷移する。上部の設定からプッシュ通知の有効化と
/// 週次メール通知の on/off を切り替えられる。
class NotificationPage extends StatelessWidget {
  const NotificationPage({
    super.key,
    this.authService,
    this.notificationService,
    this.userService,
    this.postService,
    this.pushNotificationService,
  });

  /// テスト時に差し替え可能。null の場合はビルド時に既定インスタンスを生成する。
  final AuthService? authService;
  final NotificationService? notificationService;
  final UserService? userService;
  final PostService? postService;
  final PushNotificationService? pushNotificationService;

  @override
  Widget build(BuildContext context) {
    final uid = (authService ?? AuthService()).currentUserId;
    final notifications = notificationService ?? NotificationService();

    return Scaffold(
      appBar: AppBar(
        title: const Text('通知'),
        actions: [
          if (uid != null)
            IconButton(
              icon: const Icon(Icons.done_all),
              tooltip: 'すべて既読にする',
              onPressed: () => notifications.markAllAsRead(uid),
            ),
        ],
      ),
      body: uid == null
          ? const Center(child: Text('ログイン情報が取得できませんでした'))
          : ListView(
              children: [
                _NotificationSettings(
                  uid: uid,
                  notificationService: notifications,
                  pushNotificationService: pushNotificationService,
                ),
                const Divider(height: 1),
                StreamBuilder<List<AppNotification>>(
                  stream: notifications.getNotifications(uid),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return const Padding(
                        padding: EdgeInsets.all(32),
                        child: Center(child: Text('通知を読み込めませんでした')),
                      );
                    }
                    if (!snapshot.hasData) {
                      return const Padding(
                        padding: EdgeInsets.all(32),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }

                    final items = snapshot.data!;
                    if (items.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.all(32),
                        child: Center(child: Text('通知はまだありません')),
                      );
                    }

                    return Column(
                      children: [
                        for (final notification in items)
                          _NotificationTile(
                            notification: notification,
                            onTap: () => _open(
                              context,
                              notification,
                              notifications,
                              postService ?? PostService(),
                            ),
                            userService: userService ?? UserService(),
                          ),
                      ],
                    );
                  },
                ),
              ],
            ),
    );
  }

  /// 既読にしたうえで、通知の対象（投稿またはイベント）を開く。
  Future<void> _open(
    BuildContext context,
    AppNotification notification,
    NotificationService notifications,
    PostService posts,
  ) async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    if (!notification.isRead) {
      // 既読化の失敗で遷移を妨げない。
      notifications.markAsRead(notification.id).ignore();
    }

    if (notification.targetsEvent) {
      navigator.push(
        MaterialPageRoute<void>(
          builder: (_) => EventDetailPage(eventId: notification.sourceId),
        ),
      );
      return;
    }

    if (notification.targetsPost) {
      final found = await posts.getPostsByIds([notification.sourceId]);
      if (found.isEmpty) {
        messenger.showSnackBar(const SnackBar(content: Text('対象の投稿は削除されています')));
        return;
      }
      navigator.push(
        MaterialPageRoute<void>(builder: (_) => PostDetailPage(found.first)),
      );
    }
  }
}

/// 通知 1 件の表示。通知を起こしたユーザーの名前を引いて文面を組み立てる。
class _NotificationTile extends StatefulWidget {
  const _NotificationTile({
    required this.notification,
    required this.onTap,
    required this.userService,
  });

  final AppNotification notification;
  final VoidCallback onTap;
  final UserService userService;

  @override
  State<_NotificationTile> createState() => _NotificationTileState();
}

class _NotificationTileState extends State<_NotificationTile> {
  /// 一覧の再描画（既読化など）のたびに取り直してちらつかないよう保持する。
  late Future<AppUser?> _actor = widget.userService.getUser(
    widget.notification.actorId,
  );

  @override
  void didUpdateWidget(covariant _NotificationTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.notification.actorId != widget.notification.actorId) {
      _actor = widget.userService.getUser(widget.notification.actorId);
    }
  }

  /// 通知種別ごとの文面。[actorName] は通知を起こしたユーザーの表示名。
  static String message(AppNotification notification, String actorName) {
    switch (notification.type) {
      case AppNotification.typeReaction:
        return '$actorNameさんがあなたの投稿にいいねしました';
      case AppNotification.typeComment:
        return '$actorNameさんがあなたの投稿にコメントしました';
      case AppNotification.typeEventUpdate:
        return '参加予定のイベントが更新されました';
      default:
        return '新しい通知があります';
    }
  }

  static IconData _icon(String type) {
    switch (type) {
      case AppNotification.typeReaction:
        return Icons.favorite;
      case AppNotification.typeComment:
        return Icons.chat_bubble;
      case AppNotification.typeEventUpdate:
        return Icons.event;
      default:
        return Icons.notifications;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final notification = widget.notification;
    final unread = !notification.isRead;

    return FutureBuilder<AppUser?>(
      future: _actor,
      builder: (context, snapshot) {
        final actorName = snapshot.data?.username ?? 'だれか';
        return ListTile(
          tileColor: unread
              ? colorScheme.primaryContainer.withValues(alpha: 0.35)
              : null,
          leading: CircleAvatar(
            backgroundColor: colorScheme.secondaryContainer,
            child: Icon(
              _icon(notification.type),
              color: colorScheme.onSecondaryContainer,
              size: 20,
            ),
          ),
          title: Text(
            message(notification, actorName),
            style: TextStyle(
              fontWeight: unread ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          subtitle: Text(_formatDate(notification.createdAt)),
          trailing: unread
              ? Icon(Icons.circle, size: 10, color: colorScheme.primary)
              : null,
          onTap: widget.onTap,
        );
      },
    );
  }

  static String _formatDate(DateTime date) {
    String two(int value) => value.toString().padLeft(2, '0');
    return '${date.year}/${two(date.month)}/${two(date.day)} '
        '${two(date.hour)}:${two(date.minute)}';
  }
}

/// 通知設定（プッシュ通知の有効化・週次メール通知の on/off）。
class _NotificationSettings extends StatefulWidget {
  const _NotificationSettings({
    required this.uid,
    required this.notificationService,
    this.pushNotificationService,
  });

  final String uid;
  final NotificationService notificationService;
  final PushNotificationService? pushNotificationService;

  @override
  State<_NotificationSettings> createState() => _NotificationSettingsState();
}

class _NotificationSettingsState extends State<_NotificationSettings> {
  late final PushNotificationService _push =
      widget.pushNotificationService ?? PushNotificationService();

  /// プッシュ通知の許可状態。確認中は null。
  bool? _pushEnabled;
  bool _requesting = false;

  @override
  void initState() {
    super.initState();
    _loadPushState();
  }

  Future<void> _loadPushState() async {
    bool granted;
    try {
      granted = await _push.isPermissionGranted();
    } catch (_) {
      granted = false;
    }
    if (!mounted) return;
    setState(() => _pushEnabled = granted);
  }

  Future<void> _enablePush() async {
    setState(() => _requesting = true);
    bool registered;
    try {
      registered = await _push.requestPermissionAndRegister(widget.uid);
    } catch (_) {
      registered = false;
    }
    if (!mounted) return;
    setState(() {
      _requesting = false;
      _pushEnabled = registered;
    });
    if (!registered) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('プッシュ通知を有効にできませんでした。ブラウザの通知設定を確認してください')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (_push.isSupported)
          ListTile(
            leading: const Icon(Icons.notifications_active_outlined),
            title: const Text('プッシュ通知'),
            subtitle: Text(
              _pushEnabled == true ? 'この端末で受け取ります' : 'この端末（ブラウザ）で通知を受け取ります',
            ),
            trailing: _pushEnabled == true
                ? const Icon(Icons.check_circle, color: Colors.green)
                : FilledButton.tonal(
                    onPressed: _pushEnabled == null || _requesting
                        ? null
                        : _enablePush,
                    child: const Text('有効にする'),
                  ),
          ),
        StreamBuilder<bool>(
          stream: widget.notificationService.watchEmailNotification(widget.uid),
          builder: (context, snapshot) {
            return SwitchListTile(
              secondary: const Icon(Icons.mail_outline),
              title: const Text('週次メール通知'),
              subtitle: const Text('1 週間分の未読通知をメールでまとめて受け取ります'),
              value: snapshot.data ?? true,
              onChanged: snapshot.hasData
                  ? (value) => widget.notificationService.setEmailNotification(
                      widget.uid,
                      value,
                    )
                  : null,
            );
          },
        ),
      ],
    );
  }
}
