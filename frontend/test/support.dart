import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viralforge_experiment/api/api_client.dart';
import 'package:viralforge_experiment/api/auth_service.dart';
import 'package:viralforge_experiment/models.dart';
import 'package:viralforge_experiment/router.dart';
import 'package:viralforge_experiment/state/providers.dart';
import 'package:viralforge_experiment/theme.dart';

class FakeAuth implements AuthService {
  bool signedIn;
  AuthFailure? signInError;
  bool registerNeedsConfirm = true;
  final signInCalls = <List<String>>[];
  final registerCalls = <List<String>>[];
  final _changes = StreamController<void>.broadcast();

  FakeAuth({this.signedIn = true});

  @override
  bool get isSignedIn => signedIn;
  @override
  String? get email => 'maya@example.com';
  @override
  Stream<void> get changes => _changes.stream;
  @override
  Future<String?> accessToken() async => signedIn ? 'token' : null;

  @override
  Future<bool> register(String email, String password) async {
    registerCalls.add([email, password]);
    return registerNeedsConfirm;
  }

  @override
  Future<void> signIn(String email, String password) async {
    signInCalls.add([email, password]);
    if (signInError != null) throw signInError!;
    signedIn = true;
    _changes.add(null);
  }

  @override
  Future<void> signOut() async {
    signedIn = false;
    _changes.add(null);
  }
}

Project sampleProject({String id = 'p1', String name = 'Spring recipes', int count = 0}) => Project(
      id: id,
      name: name,
      platform: 'tiktok',
      niche: 'Budget cooking',
      targetAudience: 'Students',
      analysisCount: count,
      createdAt: '2026-03-01T10:00:00+00:00',
      updatedAt: '2026-03-02T10:00:00+00:00',
    );

Job sampleJob({
  String id = 'j1',
  String status = 'completed',
  String stage = 'completed',
  int progress = 100,
  String? errorCode,
  String? errorMessage,
  bool retryable = false,
  Map<String, int>? scores,
  String inputType = 'video',
}) =>
    Job(
      id: id,
      projectId: 'p1',
      projectName: 'Spring recipes',
      videoId: inputType == 'video' ? 'v1' : null,
      inputType: inputType,
      platform: 'tiktok',
      niche: 'Budget cooking',
      targetAudience: 'Students',
      status: status,
      stage: stage,
      progress: progress,
      attempts: 1,
      maxAttempts: 3,
      errorCode: errorCode,
      errorMessage: errorMessage,
      retryable: retryable,
      scores: scores,
      createdAt: '2026-03-02T10:00:00+00:00',
    );

const sampleScores = {'hook': 80, 'engagement': 70, 'retention': 60, 'shareability': 50, 'overall': 66};

Map<String, dynamic> sampleReportJson({int personasOk = 10}) {
  final names = [
    'Maya, the fast scroller', 'Daniel, the busy parent', 'Priya, the niche enthusiast', 'Tom, the sceptic',
    'Lena, the sound-off commuter', 'Carlos, the small business owner', 'Aisha, the college student',
    'Harold, the 60+ viewer', 'Jordan, the aspiring creator', 'Mei, the non-native-English viewer',
  ];
  return {
    'scores': sampleScores,
    'verdict': 'Promising',
    'platform': 'tiktok',
    'niche': 'Budget cooking',
    'input_type': 'video',
    'content_summary': 'A creator preps three meals in ten minutes.',
    'strengths': ['Strong first second'],
    'weaknesses': ['No call to action'],
    'recommendations': [
      {'priority': 1, 'title': 'Tighten the middle', 'detail': 'Cut seconds 12 to 18.', 'expected_impact': 'high'},
      {'priority': 2, 'title': 'Add a payoff', 'detail': 'Show the finished meal.', 'expected_impact': 'medium'},
    ],
    'observations': [
      {'area': 'opening_hook', 'observation': 'Opens on the finished dish.', 'evidence': '0:00-0:02'},
    ],
    'dimensions': [
      for (final k in ['Hook strength', 'Clarity', 'Emotional appeal', 'Entertainment value', 'Information value', 'Audience retention potential', 'Shareability'])
        {'key': k, 'label': k, 'score': 7, 'rationale': 'Because of $k.'}
    ],
    'rubric': {
      'dimension_anchor': '1-2 very weak, 9-10 exceptional.',
      'rounding': 'Round half up to the nearest integer',
      'formulas': {
        'hook': 'Hook strength x 10',
        'engagement': 'Mean of four ratings x 10',
        'retention': 'Audience retention potential x 10',
        'shareability': 'Shareability x 10',
        'overall': '0.30 Hook + 0.25 Engagement + 0.25 Retention + 0.20 Shareability',
      },
      'dimensions': [
        {'key': 'clarity', 'label': 'Clarity', 'definition': 'How easily a viewer understands the point.'},
      ],
    },
    'confidence': 'high',
    'confidence_note': 'Clear audio and visuals.',
    'disclaimer': 'This report is an AI-generated estimate and cannot predict real-world performance.',
    'model': 'gemini-test',
    'generated_at': '2026-03-02T10:05:00+00:00',
    'personas': {
      'label': 'AI-simulated reactions. Not real audience research.',
      'status': personasOk == 10 ? 'complete' : (personasOk == 0 ? 'failed' : 'partial'),
      'expected': 10,
      'received': personasOk,
      'note': personasOk == 10 ? null : 'Only $personasOk of 10 persona reactions could be produced.',
      'items': [
        for (var i = 0; i < 10; i++)
          i < personasOk
              ? {
                  'persona_id': 'p$i', 'name': names[i], 'description': 'Description $i', 'status': 'ok',
                  'first_impression': 'Catchy.', 'interest_level': 7, 'likely_action': 'like',
                  'would_finish': true, 'reaction': 'Reaction text $i.', 'concern': 'Concern $i.',
                }
              : {'persona_id': 'p$i', 'name': names[i], 'description': 'Description $i', 'status': 'missing'},
      ],
    },
  };
}

class FakeApi extends Fake implements ApiClient {
  List<Project> projects = [];
  List<Job> historyJobs = [];
  List<VideoItem> videos = [];
  Map<String, JobDetail> analyses = {};
  ApiException? uploadError;
  ApiException? createAnalysisError;
  ApiException? getAnalysisError;

  final createdProjects = <Map<String, dynamic>>[];
  final uploads = <String>[];
  final createdAnalyses = <Map<String, dynamic>>[];
  final retried = <String>[];
  final deletedProjects = <String>[];

  @override
  Future<PublicConfig> getConfig() async => const PublicConfig();

  @override
  Future<Paged<Project>> listProjects({int limit = 50, int offset = 0}) async =>
      Paged(projects, projects.length, limit, offset);

  @override
  Future<Project> getProject(String id) async => projects.firstWhere((p) => p.id == id, orElse: () => sampleProject(id: id));

  @override
  Future<Project> createProject(Map<String, dynamic> body) async {
    createdProjects.add(body);
    final p = sampleProject(id: 'new1', name: body['name'] as String);
    projects = [p, ...projects];
    return p;
  }

  @override
  Future<void> deleteProject(String id) async {
    deletedProjects.add(id);
    projects = projects.where((p) => p.id != id).toList();
  }

  @override
  Future<Paged<VideoItem>> listVideos(String projectId, {int limit = 50, int offset = 0}) async =>
      Paged(videos, videos.length, limit, offset);

  @override
  Future<VideoItem> uploadVideo(String projectId, Uint8List bytes, String filename,
      {void Function(int sent, int total)? onProgress, CancelToken? cancelToken}) async {
    if (uploadError != null) throw uploadError!;
    onProgress?.call(bytes.length, bytes.length);
    uploads.add(filename);
    return VideoItem(id: 'v-${uploads.length}', projectId: projectId, filename: filename, mimeType: 'video/mp4', sizeBytes: bytes.length);
  }

  @override
  Future<Job> createAnalysis(String projectId, Map<String, dynamic> body) async {
    if (createAnalysisError != null) {
      final e = createAnalysisError!;
      createAnalysisError = null; // fail once, then succeed
      throw e;
    }
    createdAnalyses.add(body);
    final job = sampleJob(id: 'jnew', status: 'queued', stage: 'queued', progress: 0);
    analyses['jnew'] = JobDetail(job, null);
    return job;
  }

  @override
  Future<Paged<Job>> projectAnalyses(String projectId, {int limit = 50, int offset = 0}) async {
    final items = analyses.values.map((d) => d.job).toList();
    return Paged(items, items.length, limit, offset);
  }

  @override
  Future<Paged<Job>> history({int limit = 20, int offset = 0}) async => Paged(historyJobs, historyJobs.length, limit, offset);

  @override
  Future<JobDetail> getAnalysis(String id) async {
    if (getAnalysisError != null) throw getAnalysisError!;
    return analyses[id] ?? (throw const ApiException(404, 'not_found', 'Analysis not found.'));
  }

  @override
  Future<Job> retryAnalysis(String id) async {
    retried.add(id);
    final job = sampleJob(id: id, status: 'queued', stage: 'queued', progress: 0);
    analyses[id] = JobDetail(job, null);
    return job;
  }

  @override
  Future<void> deleteAnalysis(String id) async => analyses.remove(id);
}

/// Mounts the real router with fakes. Use [location] to start somewhere other than /projects.
Future<GoRouterHandle> pumpApp(
  WidgetTester tester, {
  required FakeAuth auth,
  required FakeApi api,
  String location = '/projects',
  Size size = const Size(1200, 900),
  bool settle = true,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  final router = buildRouter(auth);
  await tester.pumpWidget(ProviderScope(
    overrides: [authServiceProvider.overrideWithValue(auth), apiProvider.overrideWithValue(api)],
    child: MaterialApp.router(theme: buildTheme(webFonts: false), routerConfig: router),
  ));
  if (location != '/projects' && auth.isSignedIn) router.go(location);
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }
  return GoRouterHandle(router);
}

class GoRouterHandle {
  final dynamic router;
  GoRouterHandle(this.router);
  String get location => router.state.uri.toString() as String;
}

Uint8List fakeBytes(int n) => Uint8List(n);

class JobDetailStub {
  static JobDetail completed() => JobDetail(sampleJob(scores: sampleScores), Report(sampleReportJson()));
}
