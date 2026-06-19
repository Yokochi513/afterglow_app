import 'package:afterglow_app/models/app_user.dart';
import 'package:afterglow_app/pages/auth/login_page.dart';
import 'package:afterglow_app/pages/auth/pending_approval_page.dart';
import 'package:afterglow_app/pages/map_screen.dart';
import 'package:afterglow_app/services/auth_service.dart';
import 'package:afterglow_app/services/user_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// 認証・承認状態に応じてルート画面を切り替えるゲート。
///
/// - 未ログイン            → [LoginPage]
/// - ログイン済 / 未承認    → [PendingApprovalPage]
/// - ログイン済 / 承認済    → [MapScreen]（アプリ本体）
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();
    final userService = UserService();

    return StreamBuilder<User?>(
      stream: authService.authStateChanges,
      builder: (context, authSnapshot) {
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const _LoadingScaffold();
        }

        final user = authSnapshot.data;
        if (user == null) {
          return const LoginPage();
        }

        return StreamBuilder<AppUser?>(
          stream: userService.watchUser(user.uid),
          builder: (context, userSnapshot) {
            if (userSnapshot.connectionState == ConnectionState.waiting) {
              return const _LoadingScaffold();
            }

            final appUser = userSnapshot.data;
            if (appUser != null && appUser.approved) {
              return const MapScreen();
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
