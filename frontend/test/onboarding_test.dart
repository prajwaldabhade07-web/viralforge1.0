import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viralforge_experiment/screens/onboarding_screen.dart';
import 'package:viralforge_experiment/state/providers.dart';

import 'support.dart';

void main() {
  testWidgets('five questions, every one skippable, answers land in the profile', (tester) async {
    await pumpApp(tester, auth: FakeAuth(), api: FakeApi(), location: '/welcome');
    final c = ProviderScope.containerOf(tester.element(find.byType(OnboardingScreen)));
    expect(find.text('What should Pip call you?'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, 'Maya');
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('What do you make?'), findsOneWidget);
    await tester.tap(find.text('Cooking'));
    await tester.pump();
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('TikTok'));
    await tester.pump();
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('Who is it for?'), findsOneWidget);
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();
    expect(find.text('What do you want most?'), findsOneWidget);
    await tester.tap(find.text('Grow my followers'));
    await tester.pump();
    await tester.tap(find.text('Finish'));
    await tester.pumpAndSettle();
    expect(find.text('Drop a clip. Pip does the rest.'), findsOneWidget);
    final p = c.read(profileProvider);
    expect((p.name, p.niche, p.platform, p.audience, p.goal), ('Maya', 'Cooking', 'tiktok', '', 'Grow my followers'));
  });

  testWidgets('Skip all goes straight to the dashboard', (tester) async {
    await pumpApp(tester, auth: FakeAuth(), api: FakeApi(), location: '/welcome');
    await tester.tap(find.text('Skip all'));
    await tester.pumpAndSettle();
    expect(find.text('Drop a clip. Pip does the rest.'), findsOneWidget);
  });
}