import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viralforge_experiment/api/api_client.dart';
import 'package:viralforge_experiment/models.dart';

import 'support.dart';

FakeApi apiWith(JobDetail d) => FakeApi()
  ..projects = [sampleProject()]
  ..analyses = {d.job.id: d};

Future<void> open(WidgetTester tester, FakeApi api, {bool settle = true}) =>
    pumpApp(tester, auth: FakeAuth(), api: api, location: '/analyses/j1', settle: settle);

void main() {
  testWidgets('shows live progress while the analysis runs', (tester) async {
    final api = apiWith(JobDetail(sampleJob(status: 'processing', stage: 'analyzing', progress: 50), null));
    await open(tester, api, settle: false);
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text("Pip's watching your video"), findsOneWidget);
    expect(find.text('50%'), findsOneWidget);
    expect(find.text('Running the safety check'), findsOneWidget);
    expect(find.textContaining('You can leave this page'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('polling picks up completion and renders the full report', (tester) async {
    final api = apiWith(JobDetail(sampleJob(status: 'processing', stage: 'analyzing', progress: 50), null));
    await open(tester, api, settle: false);
    expect(find.text("Pip's watching your video"), findsOneWidget);
    api.analyses['j1'] = JobDetail(sampleJob(scores: sampleScores), Report(sampleReportJson()));
    await tester.pump(const Duration(milliseconds: 2600));
    await tester.pumpAndSettle();
    expect(find.text('Viral Readiness'), findsOneWidget);
    expect(find.text('Promising'), findsOneWidget);
  });

  testWidgets('completed report shows all five scores, rubric, advice and ten personas', (tester) async {
    final handle = tester.ensureSemantics();
    final api = apiWith(JobDetail(sampleJob(scores: sampleScores), Report(sampleReportJson())));
    await open(tester, api);
    expect(find.bySemanticsLabel('Overall score 66 out of 100'), findsOneWidget);
    // 'Shareability' is also one of the seven ratings, so it legitimately appears twice.
    for (final label in ['Hook', 'Engagement', 'Retention', 'Shareability']) {
      expect(find.text(label), findsWidgets);
    }
    expect(find.text('80'), findsOneWidget);
    expect(find.text('How these scores are calculated'), findsOneWidget);
    expect(find.text('Tighten the middle'), findsOneWidget);
    expect(find.text('Working well'), findsOneWidget);
    expect(find.textContaining('AI-simulated reactions. Not real audience research.'), findsOneWidget);
    expect(find.textContaining('Maya, the fast scroller'), findsOneWidget);
    expect(find.textContaining('Mei, the non-native-English viewer'), findsOneWidget);
    expect(find.textContaining('cannot predict real-world performance'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('recommendations can be ticked off', (tester) async {
    final api = apiWith(JobDetail(sampleJob(scores: sampleScores), Report(sampleReportJson())));
    await open(tester, api);
    expect(find.byTooltip('Mark as done'), findsNWidgets(2));
    await tester.tap(find.byTooltip('Mark as done').first);
    await tester.pump();
    expect(find.byTooltip('Mark as not done'), findsOneWidget);
  });

  testWidgets('a video that cannot load does not break the report', (tester) async {
    final api = apiWith(JobDetail(sampleJob(scores: sampleScores), Report(sampleReportJson())));
    await open(tester, api);
    expect(find.textContaining('The video could not be loaded'), findsOneWidget);
    expect(find.text('Viral Readiness'), findsOneWidget);
  });

  testWidgets('incomplete persona results are flagged, not hidden', (tester) async {
    final api = apiWith(JobDetail(sampleJob(scores: sampleScores), Report(sampleReportJson(personasOk: 6))));
    await open(tester, api);
    expect(find.textContaining('Only 6 of 10 persona reactions'), findsOneWidget);
    expect(find.text('No reaction was generated for this persona.'), findsNWidgets(4));
  });

  testWidgets('failed analysis explains why and offers a retry', (tester) async {
    final api = apiWith(JobDetail(
      sampleJob(status: 'failed', stage: 'failed', progress: 50, errorCode: 'ai_response_invalid', retryable: true,
          errorMessage: 'The AI returned a response that could not be used. Retry the analysis.'),
      null,
    ));
    await open(tester, api);
    expect(find.text("The analysis didn't finish"), findsOneWidget);
    expect(find.textContaining('could not be used'), findsOneWidget);
    await tester.tap(find.text('Retry analysis'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(api.retried, ['j1']);
    expect(find.text('Your analysis is queued'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('blocked submissions cannot be retried', (tester) async {
    final api = apiWith(JobDetail(
      sampleJob(status: 'failed', stage: 'blocked', errorCode: 'content_blocked', retryable: false,
          errorMessage: 'This submission was blocked by the content policy (graphic violence).'),
      null,
    ));
    await open(tester, api);
    expect(find.text('This submission was blocked'), findsOneWidget);
    expect(find.text('Retry analysis'), findsNothing);
    expect(find.text('Back to project'), findsWidgets);
  });

  testWidgets('unknown analysis shows a clear error', (tester) async {
    final api = FakeApi()..projects = [sampleProject()];
    await open(tester, api);
    expect(find.text('Analysis not found.'), findsOneWidget);
  });

  testWidgets('network failure on first load offers a retry', (tester) async {
    final api = FakeApi()
      ..projects = [sampleProject()]
      ..getAnalysisError = const ApiException(0, 'network_error', 'Cannot reach the ViralForge server.');
    await open(tester, api);
    expect(find.textContaining('Cannot reach'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });
}