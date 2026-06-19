import 'package:afterglow_app/services/auth_service.dart';
import 'package:flutter/material.dart';

/// 登録済みだが管理者の承認待ちのユーザーに表示する画面。
/// 承認されると AuthGate が監視している users ドキュメントの `approved` が
/// true になり、自動的にアプリ本体へ切り替わる。
class PendingApprovalPage extends StatelessWidget {
  const PendingApprovalPage({super.key, required this.email});

  final String email;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('承認待ち'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'ログアウト',
            onPressed: () => AuthService().signOut(),
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.hourglass_top, size: 64, color: Colors.deepPurple),
              const SizedBox(height: 24),
              Text(
                '管理者の承認待ちです',
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                '$email で登録しました。\n管理者が承認すると自動的にご利用いただけます。',
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              OutlinedButton.icon(
                onPressed: () => AuthService().signOut(),
                icon: const Icon(Icons.logout),
                label: const Text('ログアウト'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
