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

  testWidgets('Gauge shows score and verdict, or an empty state', (tester) async {
    await tester.pumpWidget(host(const Gauge(score: 82), h: 160));
    expect(find.text('82'), findsOneWidget);
    expect(find.text('Strong'), findsOneWidget);
    await tester.pumpWidget(host(const Gauge(score: null), h: 160));
    expect(find.text('No score yet'), findsOneWidget);
  });

  testWidgets('TrendLine handles 0, 1 and several points', (tester) async {
    await tester.pumpWidget(host(const TrendLine(points: []), h: 200));
    expect(find.text('Your trend shows up after your first report.'), findsOneWidget);
    await tester.pumpWidget(host(TrendLine(points: [pt(70)]), h: 200));
    expect(find.text('70'), findsOneWidget);
    expect(find.text('One more analysis unlocks your trend.'), findsOneWidget);
    await tester.pumpWidget(host(TrendLine(points: [pt(50), pt(70), pt(90)], prev: [pt(40), pt(55)]), h: 200));
    await tester.tapAt(tester.getCenter(find.byType(TrendLine)));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}