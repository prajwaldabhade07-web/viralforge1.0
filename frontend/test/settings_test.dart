import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viralforge_experiment/screens/settings_screen.dart';
import 'package:viralforge_experiment/state/providers.dart';

import 'support.dart';

void main() {
  testWidgets('accent swatches change the accent', (tester) async {
    await pumpApp(tester, auth: FakeAuth(), api: FakeApi(), location: '/settings');
    final c = ProviderScope.containerOf(tester.element(find.byType(SettingsScreen)));
    await tester.tap(find.byTooltip('Violet'));
    await tester.pump();
    expect(c.read(accentProvider), 1);
    c.read(accentProvider.notifier).set(0);
  });
}