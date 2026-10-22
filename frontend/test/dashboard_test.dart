import 'package:flutter_test/flutter_test.dart';

import 'support.dart';

void main() {
  testWidgets('0 analyses: how it works, quiet widgets and a Pip empty state', (tester) async {
    await pumpApp(tester, auth: FakeAuth(), api: FakeApi(), location: '/dashboard');
    expect(find.text('How it works'), findsOneWidget);
    expect(find.text('Pip watches it'), findsOneWidget);
    expect(find.text('Drop a clip. Pip does the rest.'), findsOneWidget);
    expect(find.text('Drop a video here'), findsOneWidget);
    expect(find.text('Analyses this week'), findsOneWidget);
    expect(find.text('Nothing yet this week'), findsOneWidget);
    expect(find.text("Last time's #1 fix"), findsOneWidget);
    expect(find.text("Pip's tip"), findsOneWidget);
    expect(find.text('Your bars appear after your first report.'), findsOneWidget);
    expect(find.text('Your skills show up after your first report.'), findsOneWidget);
    expect(find.text('No reports yet'), findsOneWidget);
    expect(find.text('Analysis in progress'), findsNothing);
  });

  testWidgets('1 analysis: singular wording, fix and skills from the last report', (tester) async {
    final api = FakeApi()
      ..historyJobs = [sampleJob(scores: sampleScores)]
      ..analyses = {'j1': JobDetailStub.completed()};
    await pumpApp(tester, auth: FakeAuth(), api: api, location: '/dashboard');
    expect(find.text('How it works'), findsNothing);
    expect(find.text('Across 1 analysis'), findsOneWidget);
    expect(find.text('Your first score'), findsOneWidget);
    expect(find.text('Tighten the middle'), findsOneWidget);
    expect(find.text('Hook'), findsOneWidget);
    expect(find.text('Strongest'), findsOneWidget);
    expect(find.text('Needs work'), findsOneWidget);
    expect(find.textContaining('Set '), findsOneWidget);
    expect(find.text('Spring recipes'), findsOneWidget);
  });

  testWidgets('2 analyses: change note and recent list', (tester) async {
    final api = FakeApi()
      ..historyJobs = [sampleJob(id: 'j2', scores: {'overall': 80}), sampleJob(id: 'j1', scores: {'overall': 60})];
    await pumpApp(tester, auth: FakeAuth(), api: api, location: '/dashboard');
    expect(find.text('+20 from last analysis'), findsOneWidget);
    expect(find.text('Across 2 analyses'), findsOneWidget);
    expect(find.text('Spring recipes'), findsNWidgets(2));
  });

  testWidgets('a running analysis shows a banner and a top-bar chip you can reach from anywhere', (tester) async {
    final api = FakeApi()..historyJobs = [sampleJob(id: 'j9', status: 'processing', stage: 'analyzing', progress: 40)];
    await pumpApp(tester, auth: FakeAuth(), api: api, location: '/dashboard');
    expect(find.text('Analysis in progress'), findsOneWidget);
    expect(find.text('See progress'), findsOneWidget);
    expect(find.text('Analysing 1 video'), findsOneWidget);
  });

  testWidgets('the New analysis button opens the new analysis page', (tester) async {
    await pumpApp(tester, auth: FakeAuth(), api: FakeApi(), location: '/dashboard');
    await tester.tap(find.text('New analysis'));
    await tester.pumpAndSettle();
    expect(find.text('Before you drop'), findsOneWidget);
  });
}