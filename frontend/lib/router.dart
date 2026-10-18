import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'api/auth_service.dart';
import 'screens/analysis_screen.dart';
import 'screens/auth_screen.dart';
import 'screens/forgot_password_screen.dart';
import 'screens/history_screen.dart';
import 'screens/new_analysis_screen.dart';
import 'screens/project_screen.dart';
import 'screens/projects_screen.dart';
import 'screens/shell.dart';
import 'state/providers.dart';
import 'widgets/common.dart';

/// Re-runs route redirects whenever the auth session changes (sign in, sign out, expiry).
class _AuthRefresh extends ChangeNotifier {
  late final StreamSubscription<void> _sub;
  _AuthRefresh(AuthService auth) {
    _sub = auth.changes.listen((_) => notifyListeners());
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}

GoRouter buildRouter(AuthService auth) {
  final refresh = _AuthRefresh(auth);
  return GoRouter(
    initialLocation: '/projects',
    refreshListenable: refresh,
    redirect: (context, state) {
      final loc = state.matchedLocation;
      final onLogin = loc == '/login';
      final onPublic = onLogin || loc == '/forgot-password';
      if (!auth.isSignedIn && !onPublic) return '/login';
      if (auth.isSignedIn && onLogin) return '/projects';
      return null;
    },
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: EmptyState(
          title: 'Page not found',
          body: 'That address does not match anything in ViralForge.',
          actionLabel: 'Go to projects',
          onAction: () => context.go('/projects'),
        ),
      ),
    ),
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const AuthScreen()),
      GoRoute(path: '/forgot-password', builder: (context, state) => const ForgotPasswordScreen()),
      ShellRoute(
        builder: (context, state, child) => AppShell(location: state.uri.path, child: child),
        routes: [
          GoRoute(path: '/projects', builder: (context, state) => const ProjectsScreen()),
          GoRoute(
            path: '/projects/:id',
            builder: (context, state) => ProjectScreen(projectId: state.pathParameters['id']!),
          ),
          GoRoute(
            path: '/projects/:id/new',
            builder: (context, state) => NewAnalysisScreen(
              projectId: state.pathParameters['id']!,
              existingVideoId: state.uri.queryParameters['video'],
            ),
          ),
          GoRoute(
            path: '/analyses/:id',
            builder: (context, state) => AnalysisScreen(jobId: state.pathParameters['id']!),
          ),
          GoRoute(path: '/history', builder: (context, state) => const HistoryScreen()),
        ],
      ),
    ],
  );
}

final routerProvider = Provider<GoRouter>((ref) => buildRouter(ref.watch(authServiceProvider)));