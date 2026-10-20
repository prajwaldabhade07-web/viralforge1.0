import 'package:flutter_test/flutter_test.dart';
import 'package:viralforge_experiment/widgets/charts.dart';

import 'support.dart';

void main() {
  testWidgets('0 analyses: quiet widgets, no yellow, Quick Studio and a Pip empty state', (tester) async {
    await pumpApp(tester, auth: FakeAuth(), api: FakeApi(), location: '/dashboard');
    expect(find.text('Drop a clip. Pip does the rest.'), findsOneWidget);
    expect(find.text('Drop a video here'), findsOneWidget);
    expect(find.text('Analyses this week'), findsOneWidget);
    expect(find.text('Nothing yet this week'), findsOneWidget);
    expect(find.text('No score yet'), findsOneWidget);
    expect(find.text('Your trend shows up after your first report.'), findsOneWidget);
    expect(find.text("Last time's #1 fix"), findsOneWidget);
    expect(find.text("Pip's tip"), findsOneWidget);
    expect(find.text('Your bars appear after your first report.'), findsOneWidget);
    expect(find.text('No reports yet'), findsOneWidget);
  });

  testWidgets('1 analysis: big number with a dot, singular wording, fix from the last report', (tester) async {
    final api = FakeApi()
      ..historyJobs = [sampleJob(scores: sampleScores)]
      ..analyses = {'j1': JobDetailStub.completed()};
    await pumpApp(tester, auth: FakeAuth(), api: api, location: '/dashboard');
    expect(find.text('Across 1 analysis'), findsOneWidget);
    expect(find.text('Your first score'), findsOneWidget);
    expect(find.text('Promising'), findsOneWidget);
    expect(find.text('One more analysis unlocks your trend.'), findsOneWidget);
    expect(find.text('Tighten the middle'), findsOneWidget);
    expect(find.textContaining('Set '), findsOneWidget);
    expect(find.text('Spring recipes'), findsOneWidget);
  });

  testWidgets('2 analyses: change note, sparkline and tap equivalent on the trend', (tester) async {
    final api = FakeApi()
      ..historyJobs = [sampleJob(id: 'j2', scores: {'overall': 80}), sampleJob(id: 'j1', scores: {'overall': 60})];
    await pumpApp(tester, auth: FakeAuth(), api: api, location: '/dashboard');
    expect(find.text('+20 from last analysis'), findsOneWidget);
    expect(find.text('Across 2 analyses'), findsOneWidget);
    expect(find.text('Strong'), findsOneWidget);
    expect(find.byType(TrendLine), findsOneWidget);
    await tester.tap(find.byType(TrendLine));
    await tester.pump();
    expect(find.text('Spring recipes'), findsNWidgets(2));
  });
}