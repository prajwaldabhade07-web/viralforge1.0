import 'package:flutter_test/flutter_test.dart';
import 'package:viralforge_experiment/models.dart';

import 'support.dart';

void main() {
  testWidgets('the progress page shows a plain step tracker and ways to keep working', (tester) async {
    final running = sampleJob(status: 'processing', stage: 'analyzing', progress: 50);
    final api = FakeApi()
      ..projects = [sampleProject()]
      ..historyJobs = [running]
      ..analyses = {'j1': JobDetail(running, null)};
    await pumpApp(tester, auth: FakeAuth(), api: api, location: '/analyses/j1', settle: false);
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Safety check'), findsOneWidget);
    expect(find.text('Go to dashboard'), findsOneWidget);
    expect(find.text('Analysing 1 video'), findsOneWidget);
    await tester.tap(find.text('Go to dashboard'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Dashboard'), findsWidgets);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a finished report keeps a What next bar in reach', (tester) async {
    final api = FakeApi()
      ..projects = [sampleProject()]
      ..analyses = {'j1': JobDetailStub.completed()};
    await pumpApp(tester, auth: FakeAuth(), api: api, location: '/analyses/j1');
    expect(find.text('What next?'), findsOneWidget);
    expect(find.text('Hook'), findsWidgets);
    expect(find.text('How well the first two seconds make people stop scrolling.'), findsOneWidget);
    await tester.tap(find.text('Analyse another video'));
    await tester.pumpAndSettle();
    expect(find.text('Before you drop'), findsOneWidget);
  });

  testWidgets('with several running analyses the top bar lists them', (tester) async {
    final api = FakeApi()
      ..historyJobs = [
        sampleJob(id: 'a', status: 'processing', stage: 'analyzing', progress: 30),
        sampleJob(id: 'b', status: 'queued', stage: 'queued', progress: 0),
      ];
    await pumpApp(tester, auth: FakeAuth(), api: api, location: '/dashboard');
    expect(find.text('Analysing 2 videos'), findsOneWidget);
    await tester.tap(find.text('Analysing 2 videos'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('See all reports'));
    await tester.pumpAndSettle();
    expect(find.text('Every analysis across your projects, newest first.'), findsOneWidget);
  });
}