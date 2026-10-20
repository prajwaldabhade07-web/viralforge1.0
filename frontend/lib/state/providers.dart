import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import '../api/auth_service.dart';
import '../config.dart';
import '../models.dart';
import '../util/platform.dart';

final authServiceProvider = Provider<AuthService>((ref) => SupabaseAuthService());

/// Message shown on the sign-in screen (e.g. after a session expires).
final sessionNoticeProvider = StateProvider<String?>((ref) => null);

final apiProvider = Provider<ApiClient>((ref) {
  final auth = ref.watch(authServiceProvider);
  return ApiClient(
    baseUrl: AppConfig.apiBaseUrl,
    token: auth.accessToken,
    onUnauthorized: () {
      if (auth.isSignedIn) {
        ref.read(sessionNoticeProvider.notifier).state = 'Your session expired. Sign in again.';
        auth.signOut();
      }
    },
  );
});

final publicConfigProvider = FutureProvider<PublicConfig>((ref) async {
  try {
    return await ref.watch(apiProvider).getConfig();
  } catch (_) {
    return const PublicConfig(); // sensible defaults; the server enforces the real limits
  }
});

final projectsProvider = FutureProvider.autoDispose<Paged<Project>>((ref) => ref.watch(apiProvider).listProjects());

final projectProvider =
    FutureProvider.autoDispose.family<Project, String>((ref, id) => ref.watch(apiProvider).getProject(id));

final projectVideosProvider = FutureProvider.autoDispose.family<Paged<VideoItem>, String>(
    (ref, id) => ref.watch(apiProvider).listVideos(id));

final projectAnalysesProvider =
    FutureProvider.autoDispose.family<Paged<Job>, String>((ref, id) => ref.watch(apiProvider).projectAnalyses(id));

// ───────────── Theme mode (system by default, persisted in the browser) ─────────────

class ThemeModeController extends StateNotifier<ThemeMode> {
  ThemeModeController() : super(_load());

  static ThemeMode _load() {
    switch (readPref('vf_theme')) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  void set(ThemeMode mode) {
    state = mode;
    writePref('vf_theme', mode == ThemeMode.light ? 'light' : (mode == ThemeMode.dark ? 'dark' : 'system'));
  }
}

final themeModeProvider = StateNotifierProvider<ThemeModeController, ThemeMode>((ref) => ThemeModeController());

// ───────────── Dashboard numbers, all from the existing history endpoint ─────────────

class NextFix {
  final String title;
  final String detail;
  final String jobId;
  const NextFix(this.title, this.detail, this.jobId);
}

class DashStats {
  final int total;
  final int completed;
  final double? average;
  final int? best;
  final List<int> trend; // oldest -> newest
  final List<Job> latest;
  final int? latestScore;
  final NextFix? fix;
  final int weekVideos;
  final List<bool> weekDays; // last 7 days, oldest first, today last
  const DashStats({
    this.total = 0,
    this.completed = 0,
    this.average,
    this.best,
    this.trend = const [],
    this.latest = const [],
    this.latestScore,
    this.fix,
    this.weekVideos = 0,
    this.weekDays = const [false, false, false, false, false, false, false],
  });
}

final dashboardStatsProvider = FutureProvider.autoDispose<DashStats>((ref) async {
  final api = ref.watch(apiProvider);
  try {
    final page = await api.history(limit: 30);
    final scored = page.items.where((j) => j.overall != null).toList(); // newest first
    final scores = scored.map((j) => j.overall!).toList();

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final days = List<bool>.filled(7, false);
    var week = 0;
    for (final j in page.items) {
      final d = DateTime.tryParse(j.createdAt)?.toLocal();
      if (d == null || j.inputType != 'video') continue;
      final ago = today.difference(DateTime(d.year, d.month, d.day)).inDays;
      if (ago >= 0 && ago < 7) {
        days[6 - ago] = true;
        week++;
      }
    }

    NextFix? fix;
    if (scored.isNotEmpty) {
      try {
        final detail = await api.getAnalysis(scored.first.id);
        final recs = detail.report?.recommendations ?? const <Map<String, dynamic>>[];
        if (recs.isNotEmpty) {
          fix = NextFix('${recs.first['title']}', '${recs.first['detail']}', scored.first.id);
        }
      } catch (_) {
        // The card simply shows its empty text.
      }
    }

    return DashStats(
      total: page.total,
      completed: scores.length,
      average: scores.isEmpty ? null : scores.reduce((a, b) => a + b) / scores.length,
      best: scores.isEmpty ? null : scores.reduce((a, b) => a > b ? a : b),
      trend: scores.take(8).toList().reversed.toList(),
      latest: page.items.take(3).toList(),
      latestScore: scores.isEmpty ? null : scores.first,
      fix: fix,
      weekVideos: week,
      weekDays: days,
    );
  } catch (_) {
    return const DashStats();
  }
});