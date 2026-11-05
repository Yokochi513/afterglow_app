import 'package:provider/provider.dart';
import 'package:afterglow_app/data/models/app_user.dart';
import 'package:afterglow_app/ui/auth/login_page.dart';
import 'package:afterglow_app/ui/auth/pending_approval_page.dart';
import 'package:afterglow_app/app/main_shell.dart';
import 'package:afterglow_app/data/repositories/auth_repository.dart';
import 'package:afterglow_app/data/repositories/user_repository.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// 認証・承認状態に応じてルート画面を切り替えるゲート。
///
/// - 未ログイン            → [LoginPage]
/// - ログイン済 / 未承認    → [PendingApprovalPage]
/// - ログイン済 / 承認済    → [MainShell]（アプリ本体）
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final authRepository = context.read<AuthRepository>();
    final userRepository = context.read<UserRepository>();

    return StreamBuilder<User?>(
      stream: authRepository.authStateChanges,
      builder: (context, authSnapshot) {
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const _LoadingScaffold();
        }

        final user = authSnapshot.data;
        if (user == null) {
          return const LoginPage();
        }

        return StreamBuilder<AppUser?>(
          stream: userRepository.watchUser(user.uid),
          builder: (context, userSnapshot) {
            if (userSnapshot.connectionState == ConnectionState.waiting) {
              return const _LoadingScaffold();
            }

            final appUser = userSnapshot.data;
            if (appUser != null && appUser.approved) {
              return const MainShell();
            }

            return PendingApprovalPage(email: user.email ?? '');
          },
        );
      },
    );
  }
}

class _LoadingScaffold extends StatelessWidget {
  const _LoadingScaffold();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
