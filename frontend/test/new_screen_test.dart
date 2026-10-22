import 'package:flutter_test/flutter_test.dart';

import 'support.dart';

void main() {
  testWidgets('the new analysis page has Quick Studio and tips', (tester) async {
    await pumpApp(tester, auth: FakeAuth(), api: FakeApi(), location: '/new');
    expect(find.text('New analysis'), findsOneWidget);
    expect(find.text('Drop a clip. Pip does the rest.'), findsOneWidget);
    expect(find.text('Drop a video here'), findsOneWidget);
    expect(find.text('Before you drop'), findsOneWidget);
    await tester.tap(find.text('Open projects'));
    await tester.pumpAndSettle();
    expect(find.text('No projects yet'), findsOneWidget);
  });
}