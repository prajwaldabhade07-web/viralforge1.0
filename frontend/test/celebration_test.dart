import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viralforge_experiment/theme.dart';
import 'package:viralforge_experiment/widgets/celebration.dart';

Widget _host(Widget child) => MaterialApp(theme: buildTheme(webFonts: false), home: Scaffold(body: child));

void main() {
  testWidgets('shows the report straight away when not playing', (tester) async {
    await tester.pumpWidget(_host(const ReportReveal(child: Text('THE REPORT'))));
    expect(find.text('THE REPORT'), findsOneWidget);
    expect(find.text('Your report is ready'), findsNothing);
  });

  testWidgets('plays the celebration, then leaves the report in place', (tester) async {
    var done = false;
    await tester.pumpWidget(_host(ReportReveal(play: true, onDone: () => done = true, child: const Text('THE REPORT'))));
    Fx.enabled = true; // buildTheme switches motion off for tests; this show needs it
    addTearDown(() => Fx.enabled = false);
    await tester.pumpWidget(_host(ReportReveal(key: const ValueKey('b'), play: true, onDone: () => done = true, child: const Text('THE REPORT'))));
    await tester.pump(const Duration(milliseconds: 900));
    expect(find.text('Your report is ready'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 4000));
    await tester.pump();
    expect(done, isTrue);
    expect(find.text('Your report is ready'), findsNothing);
    expect(find.text('THE REPORT'), findsOneWidget);
  });

  testWidgets('tapping skips the animation', (tester) async {
    Fx.enabled = true;
    addTearDown(() => Fx.enabled = false);
    var done = false;
    await tester.pumpWidget(_host(ReportReveal(play: true, onDone: () => done = true, child: const Text('THE REPORT'))));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.tap(find.text('Your report is ready'), warnIfMissed: false);
    await tester.pump();
    expect(done, isTrue);
    expect(find.text('Your report is ready'), findsNothing);
  });
}
