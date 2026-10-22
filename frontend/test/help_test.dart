import 'package:flutter_test/flutter_test.dart';

import 'support.dart';

void main() {
  testWidgets('the help page explains the steps, the scores and the common questions', (tester) async {
    await pumpApp(tester, auth: FakeAuth(), api: FakeApi(), location: '/help');
    expect(find.text('How it works'), findsOneWidget);
    expect(find.text('What the scores mean'), findsOneWidget);
    expect(find.text('Common questions'), findsOneWidget);
    await tester.tap(find.text('Where do I find my report?'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Open History in the left menu'), findsOneWidget);
  });
}