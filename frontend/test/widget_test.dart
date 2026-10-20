import 'package:flutter_test/flutter_test.dart';
import 'package:viralforge_experiment/util/text.dart';

void main() {
  test('plural', () {
    expect(plural(1, 'analysis', 'analyses'), '1 analysis');
    expect(plural(2, 'analysis', 'analyses'), '2 analyses');
    expect(plural(0, 'analysis', 'analyses'), '0 analyses');
  });

  test('verdictFor bands', () {
    expect(verdictFor(90), 'Exceptional');
    expect(verdictFor(75), 'Strong');
    expect(verdictFor(74), 'Promising');
    expect(verdictFor(40), 'Developing');
    expect(verdictFor(39), 'Needs rework');
  });

  test('delta and shortDate', () {
    expect(delta(4, 'from last analysis', 'Same'), '+4 from last analysis');
    expect(delta(-3, 'vs last week', 'Same'), '-3 vs last week');
    expect(delta(0, 'vs last week', 'Same as last week'), 'Same as last week');
    expect(shortDate(DateTime(2026, 3, 2)), '2 Mar');
    expect(shortDate(null), '');
  });
}