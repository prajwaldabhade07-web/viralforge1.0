import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'api/auth_service.dart';
import 'screens/analysis_screen.dart';
import 'screens/auth_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/forgot_password_screen.dart';
import 'screens/help_screen.dart';
import 'screens/history_screen.dart';
import 'screens/new_analysis_screen.dart';
import 'screens/new_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/project_screen.dart';
import 'screens/projects_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/shell.dart';
import 'state/providers.dart';
import 'theme.dart';
import 'util/profile.dart';
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

/// Page changes cross-fade (200 ms, ease-out); instant when motion is off.
Page<void> _fade(BuildContext context, GoRouterState state, Widget child) {
  final d = (Fx.enabled && !(MediaQuery.maybeOf(context)?.disableAnimations ?? false))
      ? const Duration(milliseconds: 200)
      : Duration.zero;
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: d,
    reverseTransitionDuration: d,
    transitionsBuilder: (context, anim, secondary, c) =>
        FadeTransition(opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut), child: c),
  );
}

GoRouter buildRouter(AuthService auth) {
  final refresh = _AuthRefresh(auth);
  return GoRouter(
    initialLocation: '/dashboard',
    refreshListenable: refresh,
    redirect: (context, state) {
      final loc = state.matchedLocation;
      final onLogin = loc == '/login';
      final onPublic = onLogin || loc == '/forgot-password';
      if (!auth.isSignedIn && !onPublic) return '/login';
      if (auth.isSignedIn && onLogin) return onboardingDone(auth.email) ? '/dashboard' : '/welcome';
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
      GoRoute(path: '/welcome', builder: (context, state) => const OnboardingScreen()),
      ShellRoute(
        builder: (context, state, child) => AppShell(location: state.uri.path, child: child),
        routes: [
          GoRoute(path: '/dashboard', pageBuilder: (c, s) => _fade(c, s, const DashboardScreen())),
          GoRoute(path: '/new', pageBuilder: (c, s) => _fade(c, s, const NewScreen())),
          GoRoute(path: '/projects', pageBuilder: (c, s) => _fade(c, s, const ProjectsScreen())),
          GoRoute(
            path: '/projects/:id',
            pageBuilder: (c, s) => _fade(c, s, ProjectScreen(projectId: s.pathParameters['id']!)),
          ),
          GoRoute(
            path: '/projects/:id/new',
            pageBuilder: (c, s) => _fade(
                c, s, NewAnalysisScreen(projectId: s.pathParameters['id']!, existingVideoId: s.uri.queryParameters['video'])),
          ),
          GoRoute(
            path: '/analyses/:id',
            pageBuilder: (c, s) => _fade(c, s, AnalysisScreen(jobId: s.pathParameters['id']!)),
          ),
          GoRoute(path: '/history', pageBuilder: (c, s) => _fade(c, s, const HistoryScreen())),
          GoRoute(path: '/profile', pageBuilder: (c, s) => _fade(c, s, const ProfileScreen())),
          GoRoute(path: '/settings', pageBuilder: (c, s) => _fade(c, s, const SettingsScreen())),
          GoRoute(path: '/help', pageBuilder: (c, s) => _fade(c, s, const HelpScreen())),
        ],
      ),
    ],
  );
}

final routerProvider = Provider<GoRouter>((ref) => buildRouter(ref.watch(authServiceProvider)));