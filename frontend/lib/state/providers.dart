import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import '../api/auth_service.dart';
import '../config.dart';
import '../models.dart';

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

/// Numbers for the dashboard, computed from the user's history (no backend change needed).
class DashStats {
  final int total;
  final int completed;
  final double? average;
  final int? best;
  final List<int> trend; // oldest -> newest
  final List<Job> latest;
  const DashStats({
    this.total = 0,
    this.completed = 0,
    this.average,
    this.best,
    this.trend = const [],
    this.latest = const [],
  });
}

final dashboardStatsProvider = FutureProvider.autoDispose<DashStats>((ref) async {
  try {
    final page = await ref.watch(apiProvider).history(limit: 30);
    final scores = page.items.where((j) => j.overall != null).map((j) => j.overall!).toList();
    return DashStats(
      total: page.total,
      completed: scores.length,
      average: scores.isEmpty ? null : scores.reduce((a, b) => a + b) / scores.length,
      best: scores.isEmpty ? null : scores.reduce((a, b) => a > b ? a : b),
      trend: scores.take(8).toList().reversed.toList(),
      latest: page.items.take(3).toList(),
    );
  } catch (_) {
    return const DashStats();
  }
});