import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viralforge_experiment/app.dart';
import 'package:viralforge_experiment/state/providers.dart';

import 'support.dart';

void main() {
  testWidgets('app boots to the sign-in screen when signed out', (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        authServiceProvider.overrideWithValue(FakeAuth(signedIn: false)),
        apiProvider.overrideWithValue(FakeApi()),
      ],
      child: const ViralForgeApp(webFonts: false),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Sign in'), findsWidgets);
    expect(find.text('ViralForge'), findsWidgets);
  });

  testWidgets('missing configuration shows setup guidance', (tester) async {
    await tester.pumpWidget(const ConfigErrorApp());
    expect(find.textContaining('not configured'), findsOneWidget);
  });
}
