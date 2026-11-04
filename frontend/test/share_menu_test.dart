import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viralforge_experiment/api/api_client.dart';
import 'package:viralforge_experiment/models.dart';

import 'support.dart';

void main() {
  testWidgets('a finished report offers share and download options', (tester) async {
    final api = FakeApi()
      ..projects = [sampleProject()]
      ..analyses = {'j1': JobDetail(sampleJob(scores: sampleScores), Report(sampleReportJson()))};
    await pumpApp(tester, auth: FakeAuth(), api: api, location: '/analyses/j1');
    expect(find.byTooltip('Share or download report'), findsOneWidget);
    await tester.tap(find.byTooltip('Share or download report'));
    await tester.pumpAndSettle();
    expect(find.text('Share summary'), findsOneWidget);
    expect(find.text('Copy summary'), findsOneWidget);
    expect(find.text('Download report (HTML)'), findsOneWidget);
    expect(find.text('Download as text'), findsOneWidget);
    expect(find.text('Print or save as PDF'), findsOneWidget);
    await tester.tap(find.text('Copy summary'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Summary copied'), findsOneWidget);
  });

  testWidgets('no share menu while the analysis is still running', (tester) async {
    final api = FakeApi()
      ..projects = [sampleProject()]
      ..analyses = {'j1': JobDetail(sampleJob(status: 'processing', stage: 'analyzing', progress: 50), null)};
    await pumpApp(tester, auth: FakeAuth(), api: api, location: '/analyses/j1', settle: false);
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byTooltip('Share or download report'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
}
