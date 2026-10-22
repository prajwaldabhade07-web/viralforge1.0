import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import '../api/auth_service.dart';
import '../config.dart';
import '../models.dart';
import '../theme.dart';
import '../util/platform.dart';
import '../util/profile.dart';

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

/// Analyses that are queued or running right now (newest first). The shell polls this so a running analysis is always one tap away.
final activeJobsProvider = FutureProvider.autoDispose<List<Job>>((ref) async {
  try {
    return (await ref.watch(apiProvider).history(limit: 10)).items.where((j) => j.isActive).toList();
  } catch (_) {
    return const [];
  }
});

// ───────────── Theme mode, accent and profile (persisted in the browser) ─────────────

class ThemeModeController extends StateNotifier<ThemeMode> {
  ThemeModeController() : super(_load());

  static ThemeMode _load() => switch (readPref('vf_theme')) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };

  void set(ThemeMode mode) {
    state = mode;
    writePref('vf_theme', mode == ThemeMode.light ? 'light' : (mode == ThemeMode.dark ? 'dark' : 'system'));
  }
}

final themeModeProvider = StateNotifierProvider<ThemeModeController, ThemeMode>((ref) => ThemeModeController());

class AccentController extends StateNotifier<int> {
  AccentController() : super(_load());

  static int _load() {
    final i = int.tryParse(readPref('vf_accent') ?? '');
    return (i != null && i >= 0 && i < kAccents.length) ? i : 0;
  }

  void set(int i) {
    state = i;
    writePref('vf_accent', '$i');
  }
}

final accentProvider = StateNotifierProvider<AccentController, int>((ref) => AccentController());

class ProfileController extends StateNotifier<Profile> {
  ProfileController() : super(Profile.load());

  void set(Profile p) {
    state = p;
    p.save();
  }
}

final profileProvider = StateNotifierProvider<ProfileController, Profile>((ref) => ProfileController());

// ───────────── Dashboard numbers, all from the existing history endpoint ─────────────

class NextFix {
  final String title;
  final String detail;
  final String jobId;
  const NextFix(this.title, this.detail, this.jobId);
}

class ScorePoint {
  final int score;
  final DateTime? at;
  final String id;
  const ScorePoint(this.score, this.at, this.id);
}

class DashStats {
  final int total;
  final int completed;
  final int weekVideos;
  final int weekPrev;
  final double? average;
  final ScorePoint? best;
  final List<ScorePoint> points; // last 12 scores, oldest -> newest
  final List<Job> latest;
  final NextFix? fix;
  final Map<String, int> skills; // hook, engagement, retention, shareability of the latest report
  const DashStats({
    this.total = 0,
    this.completed = 0,
    this.weekVideos = 0,
    this.weekPrev = 0,
    this.average,
    this.best,
    this.points = const [],
    this.latest = const [],
    this.fix,
    this.skills = const {},
  });

  ScorePoint? get last => points.isEmpty ? null : points.last;
  int? get change => points.length > 1 ? points.last.score - points[points.length - 2].score : null;
}

final dashboardStatsProvider = FutureProvider.autoDispose<DashStats>((ref) async {
  final api = ref.watch(apiProvider);
  try {
    final page = await api.history(limit: 30);
    final scored = page.items.where((j) => j.overall != null).toList(); // newest first
    final all = [for (final j in scored) ScorePoint(j.overall!, DateTime.tryParse(j.createdAt)?.toLocal(), j.id)];

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    int within(int from, int to) => page.items.where((j) {
          final d = DateTime.tryParse(j.createdAt)?.toLocal();
          if (d == null) return false;
          final ago = today.difference(DateTime(d.year, d.month, d.day)).inDays;
          return ago >= from && ago < to;
        }).length;

    NextFix? fix;
    var skills = const <String, int>{};
    if (scored.isNotEmpty) {
      try {
        final report = (await api.getAnalysis(scored.first.id)).report;
        final recs = report?.recommendations ?? const <Map<String, dynamic>>[];
        if (recs.isNotEmpty) fix = NextFix('${recs.first['title']}', '${recs.first['detail']}', scored.first.id);
        if (report != null) {
          skills = {
            for (final k in const ['hook', 'engagement', 'retention', 'shareability'])
              if (report.scores[k] != null) k: report.scores[k]!,
          };
        }
      } catch (_) {
        // The cards simply show their empty text.
      }
    }

    return DashStats(
      total: page.total,
      completed: all.length,
      weekVideos: within(0, 7),
      weekPrev: within(7, 14),
      average: all.isEmpty ? null : all.map((e) => e.score).reduce((a, b) => a + b) / all.length,
      best: all.isEmpty ? null : all.reduce((a, b) => b.score > a.score ? b : a),
      points: all.take(12).toList().reversed.toList(),
      latest: page.items.take(3).toList(),
      fix: fix,
      skills: skills,
    );
  } catch (_) {
    return const DashStats();
  }
});