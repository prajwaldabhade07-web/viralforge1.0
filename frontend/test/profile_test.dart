import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viralforge_experiment/screens/profile_screen.dart';
import 'package:viralforge_experiment/state/providers.dart';

import 'support.dart';

void main() {
  testWidgets('profile edits are saved and shown in the account menu', (tester) async {
    await pumpApp(tester, auth: FakeAuth(), api: FakeApi(), location: '/profile');
    final c = ProviderScope.containerOf(tester.element(find.byType(ProfileScreen)));
    await tester.enterText(find.byType(TextFormField).first, 'Zoe');
    await tester.tap(find.text('Fitness').first, warnIfMissed: false);
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();
    expect(find.text('Profile saved.'), findsOneWidget);
    expect(c.read(profileProvider).name, 'Zoe');
    expect(find.text('Zoe'), findsWidgets);
  });

  testWidgets('a short new password is rejected', (tester) async {
    await pumpApp(tester, auth: FakeAuth(), api: FakeApi(), location: '/profile');
    await tester.enterText(find.widgetWithText(TextFormField, 'New password'), 'short');
    await tester.tap(find.text('Update password'));
    await tester.pump();
    expect(find.text('Use at least 8 characters.'), findsOneWidget);
  });
}