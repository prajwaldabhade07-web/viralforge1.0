import 'package:flutter_test/flutter_test.dart';

import 'support.dart';

void main() {
  testWidgets('lists analyses across projects with scores and opens one', (tester) async {
    final api = FakeApi()
      ..historyJobs = [sampleJob(scores: sampleScores), sampleJob(id: 'j2', status: 'processing', stage: 'analyzing', progress: 50)]
      ..analyses = {'j1': JobDetailStub.completed()};
    await pumpApp(tester, auth: FakeAuth(), api: api, location: '/history');
    expect(find.text('History'), findsWidgets);
    expect(find.text('Spring recipes'), findsNWidgets(2));
    expect(find.text('66'), findsOneWidget);
    expect(find.text('Analysing'), findsOneWidget);
    await tester.tap(find.text('66'));
    await tester.pumpAndSettle();
    expect(find.text('Viral Readiness'), findsOneWidget);
  });

  testWidgets('empty history points back to projects', (tester) async {
    await pumpApp(tester, auth: FakeAuth(), api: FakeApi(), location: '/history');
    expect(find.text('No analyses yet'), findsOneWidget);
    await tester.tap(find.text('Go to projects'));
    await tester.pumpAndSettle();
    expect(find.text('No projects yet'), findsOneWidget);
  });
}
