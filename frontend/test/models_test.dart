import 'package:flutter_test/flutter_test.dart';
import 'package:viralforge_experiment/models.dart';

import 'support.dart';

void main() {
  test('Job parses status helpers and scores', () {
    final j = Job.fromJson({
      'id': 'j', 'project_id': 'p', 'input_type': 'video', 'platform': 'tiktok', 'niche': 'n',
      'target_audience': 'a', 'status': 'failed', 'stage': 'blocked', 'progress': 35, 'attempts': 1,
      'max_attempts': 3, 'error_code': 'content_blocked', 'retryable': false,
      'scores': {'overall': 61, 'hook': 70}, 'created_at': '2026-01-01T00:00:00+00:00',
    });
    expect(j.isBlocked, isTrue);
    expect(j.isActive, isFalse);
    expect(j.overall, 61);
    expect(Job.fromJson({...{'id': 'j', 'project_id': 'p', 'status': 'processing'}}).isActive, isTrue);
  });

  test('JobDetail parses an embedded report', () {
    final d = JobDetail.fromJson({
      'id': 'j', 'project_id': 'p', 'status': 'completed', 'report': sampleReportJson(),
    });
    expect(d.report, isNotNull);
    expect(d.report!.overall, 66);
    expect(d.report!.scores.keys, containsAll(['hook', 'engagement', 'retention', 'shareability', 'overall']));
    expect(d.report!.recommendations.first['title'], 'Tighten the middle');
    expect(d.report!.formulas['overall'], contains('0.30'));
  });

  test('Personas report completeness', () {
    final full = Report(sampleReportJson()).personas;
    expect(full.status, 'complete');
    expect(full.items.length, 10);
    final partial = Report(sampleReportJson(personasOk: 4)).personas;
    expect(partial.status, 'partial');
    expect(partial.received, 4);
    expect(partial.items.where((i) => i['status'] == 'missing').length, 6);
    expect(Report(sampleReportJson(personasOk: 0)).personas.status, 'failed');
  });

  test('Paged.hasMore', () {
    final p = Paged.parse({'items': [{'id': 'p1', 'name': 'x'}], 'total': 3, 'limit': 1, 'offset': 0}, Project.fromJson);
    expect(p.items.length, 1);
    expect(p.hasMore, isTrue);
  });
}
