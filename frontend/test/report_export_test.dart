import 'package:flutter_test/flutter_test.dart';
import 'package:viralforge_experiment/models.dart';
import 'package:viralforge_experiment/util/report_export.dart';

import 'support.dart';

void main() {
  final report = Report(sampleReportJson());

  test('share text is a short summary with scores, strengths and top fixes', () {
    final t = reportShareText(report, projectName: 'Spring recipes');
    expect(t, contains('ViralForge Viral Readiness Report'));
    expect(t, contains('Spring recipes · TikTok · Budget cooking'));
    expect(t, contains('Overall: 66/100 (Promising)'));
    expect(t, contains('Hook 80 · Engagement 70 · Retention 60 · Shareability 50'));
    expect(t, contains('- Strong first second'));
    expect(t, contains('1. Tighten the middle'));
    expect(t, contains('not a prediction'));
    expect(t, isNot(contains('Reaction text')));
  });

  test('full text contains every section', () {
    final t = reportFullText(report, projectName: 'Spring recipes');
    for (final s in ['SCORES', 'FIXES, IN ORDER', 'WORKING WELL', 'HOLDING IT BACK', 'HOW TEN VIEWERS REACTED', 'THE SEVEN RATINGS', 'MOMENTS IN THE VIDEO']) {
      expect(t, contains(s));
    }
    expect(t, contains('Reaction text 9.'));
    expect(t, contains('Cut seconds 12 to 18.'));
    expect(t, contains('cannot predict real-world performance'));
  });

  test('missing personas are reported as such, not invented', () {
    final t = reportFullText(Report(sampleReportJson(personasOk: 6)));
    expect(t, contains('no reaction was generated'));
  });

  test('HTML is self-contained, escaped, and prints itself only when asked', () {
    final json = sampleReportJson();
    json['content_summary'] = 'Uses <b>bold</b> & "quotes"';
    final html = reportHtml(Report(json), projectName: 'A <script>x</script>');
    expect(html, contains('&lt;b&gt;bold&lt;/b&gt; &amp; &quot;quotes&quot;'));
    expect(html, isNot(contains('<script>x</script>')));
    expect(html, isNot(contains('window.print')));
    expect(html, isNot(contains('http://')));
    expect(reportHtml(report, autoPrint: true), contains('window.print'));
  });

  test('file names are safe and dated', () {
    expect(reportFileName(report, projectName: 'Spring / recipes!', ext: 'html'),
        matches(RegExp(r'^viralforge-report-spring-recipes-\d{4}-\d{2}-\d{2}\.html$')));
    expect(reportFileName(report, ext: 'txt'), matches(RegExp(r'^viralforge-report-\d{4}-\d{2}-\d{2}\.txt$')));
  });
}
