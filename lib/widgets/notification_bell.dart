import 'package:afterglow_app/pages/notification_page.dart';
import 'package:afterglow_app/services/auth_service.dart';
import 'package:afterglow_app/services/notification_service.dart';
import 'package:flutter/material.dart';

/// AppBar に置く通知ベル（PS_07）。未読件数をバッジで示し、タップで
/// [NotificationPage] を開く。
class NotificationBell extends StatelessWidget {
  const NotificationBell({
    super.key,
    this.authService,
    this.notificationService,
  });

  /// テスト時に差し替え可能。null の場合はビルド時に既定インスタンスを生成する。
  final AuthService? authService;
  final NotificationService? notificationService;

  @override
  Widget build(BuildContext context) {
    final uid = (authService ?? AuthService()).currentUserId;
    final notifications = notificationService ?? NotificationService();

    void open() {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => NotificationPage(
            authService: authService,
            notificationService: notificationService,
          ),
        ),
      );
    }

    if (uid == null) {
      return IconButton(
        icon: const Icon(Icons.notifications_none),
        tooltip: '通知',
        onPressed: open,
      );
    }

    return StreamBuilder<int>(
      stream: notifications.watchUnreadCount(uid),
      builder: (context, snapshot) {
        final unread = snapshot.data ?? 0;
        return IconButton(
          tooltip: unread > 0 ? '通知（未読 $unread 件）' : '通知',
          onPressed: open,
          icon: Badge(
            isLabelVisible: unread > 0,
            label: Text(unread > 99 ? '99+' : '$unread'),
            child: Icon(
              unread > 0 ? Icons.notifications : Icons.notifications_none,
            ),
          ),
        );
      },
    );
  }
}
