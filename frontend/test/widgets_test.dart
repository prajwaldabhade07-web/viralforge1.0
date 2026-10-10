import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viralforge_experiment/theme.dart';
import 'package:viralforge_experiment/widgets/common.dart';
import 'package:viralforge_experiment/widgets/frame_strip.dart';

Widget host(Widget child) => MaterialApp(theme: buildTheme(webFonts: false), home: Scaffold(body: Center(child: SizedBox(width: 400, child: child))));

void main() {
  testWidgets('FrameStrip exposes its score to screen readers', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(host(const FrameStrip(value: 72, animate: false)));
    expect(find.bySemanticsLabel('Score 72 out of 100'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('FrameStrip clamps out-of-range values', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(host(const FrameStrip(value: 250, animate: false)));
    expect(find.bySemanticsLabel('Score 100 out of 100'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('StatusPill labels', (tester) async {
    await tester.pumpWidget(host(const Column(children: [
      StatusPill('queued'),
      StatusPill('processing'),
      StatusPill('completed'),
      StatusPill('failed'),
      StatusPill('failed', blocked: true),
    ])));
    for (final label in ['Queued', 'Analysing', 'Complete', 'Failed', 'Blocked']) {
      expect(find.text(label), findsOneWidget);
    }
  });

  testWidgets('EmptyState action fires', (tester) async {
    var taps = 0;
    await tester.pumpWidget(host(EmptyState(title: 'Nothing yet', body: 'Add one.', actionLabel: 'Add', onAction: () => taps++)));
    await tester.tap(find.text('Add'));
    expect(taps, 1);
  });
}
