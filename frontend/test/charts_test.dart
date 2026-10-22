import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viralforge_experiment/state/providers.dart';
import 'package:viralforge_experiment/theme.dart';
import 'package:viralforge_experiment/widgets/charts.dart';

Widget host(Widget child, {double w = 400, double? h}) => MaterialApp(
      theme: buildTheme(webFonts: false),
      home: Scaffold(body: Center(child: SizedBox(width: w, height: h, child: child))),
    );

ScorePoint pt(int s) => ScorePoint(s, null, 'j$s');

void main() {
  testWidgets('KpiCard shows label, value and note, and its arrow is tappable', (tester) async {
    var taps = 0;
    await tester.pumpWidget(host(KpiCard(label: 'Best score', value: 88, note: 'Set 2 Mar', onTap: () => taps++)));
    expect(find.text('Best score'), findsOneWidget);
    expect(find.text('88'), findsOneWidget);
    expect(find.text('Set 2 Mar'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.arrow_outward));
    expect(taps, 1);
  });

  testWidgets('KpiCard without a value shows a dash and a disabled arrow', (tester) async {
    await tester.pumpWidget(host(const KpiCard(label: 'Best score', value: null, note: 'Nothing to beat yet')));
    expect(find.text('-'), findsOneWidget);
  });

  testWidgets('PillBars fills seven slots and gives every bar a tap tooltip', (tester) async {
    await tester.pumpWidget(host(PillBars(points: [pt(60), pt(80), pt(90)]), h: 200));
    expect(find.byType(Tooltip), findsNWidgets(7));
    expect(find.byTooltip('90/100'), findsOneWidget);
    expect(find.byTooltip('No analysis yet'), findsNWidgets(4));
  });

  testWidgets('SkillBars marks the strongest and weakest skill', (tester) async {
    await tester.pumpWidget(host(const SkillBars(scores: {'hook': 80, 'engagement': 70, 'retention': 60, 'shareability': 50}), h: 400));
    expect(find.text('Hook'), findsOneWidget);
    expect(find.text('Strongest'), findsOneWidget);
    expect(find.text('Needs work'), findsOneWidget);
  });

  testWidgets('SkillBars shows a Pip empty state with no scores', (tester) async {
    await tester.pumpWidget(host(const SkillBars(scores: {}), h: 300));
    expect(find.text('Your skills show up after your first report.'), findsOneWidget);
  });
}