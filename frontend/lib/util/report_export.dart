// Turns a finished report into shareable text and a standalone, printable HTML page.
// Pure Dart (no browser APIs), so it is unit-tested. The backend is not involved: everything
// here is built from the report the app has already loaded.
import '../models.dart';
import 'format.dart';
import 'text.dart';

const _scoreLabels = <(String, String)>[
  ('hook', 'Hook'),
  ('engagement', 'Engagement'),
  ('retention', 'Retention'),
  ('shareability', 'Shareability'),
];

const _areaLabels = {
  'opening_hook': 'Opening hook',
  'visual_storytelling': 'Visual storytelling',
  'pacing': 'Pacing',
  'audio_speech': 'Audio and speech',
  'on_screen_text': 'On-screen text',
};

const _actionLabels = {
  'share': 'Would share it',
  'like': 'Would like it',
  'comment': 'Would comment',
  'follow': 'Would follow',
  'keep_scrolling': 'Would keep scrolling',
};

const _shortDisclaimer = 'AI-generated opinion, not a prediction of real performance.';

String _s(Object? v) => '${v ?? ''}'.trim();

String _verdict(Report r) => r.verdict.isEmpty ? verdictFor(r.overall) : r.verdict;

List<String> _meta(Report r, String? projectName) => [
      if (projectName != null && projectName.trim().isNotEmpty) projectName.trim(),
      if (r.platform.isNotEmpty) platformLabel(r.platform),
      if (r.niche.isNotEmpty) r.niche,
    ];

String _scoreLine(Report r) =>
    _scoreLabels.map((e) => '${e.$2} ${r.scores[e.$1] ?? 0}').join(' · ');

/// A short summary that is pleasant to paste into a chat or post: scores, top strengths, top fixes.
String reportShareText(Report r, {String? projectName}) {
  final b = StringBuffer()..writeln('ViralForge Viral Readiness Report');
  final meta = _meta(r, projectName);
  if (meta.isNotEmpty) b.writeln(meta.join(' · '));
  b
    ..writeln()
    ..writeln('Overall: ${r.overall}/100 (${_verdict(r)})')
    ..writeln(_scoreLine(r));
  if (r.summary.isNotEmpty) {
    b
      ..writeln()
      ..writeln(r.summary);
  }
  final strengths = r.strengths.take(3).toList();
  if (strengths.isNotEmpty) {
    b
      ..writeln()
      ..writeln('Working well:');
    for (final s in strengths) {
      b.writeln('- $s');
    }
  }
  final fixes = r.recommendations.take(3).toList();
  if (fixes.isNotEmpty) {
    b
      ..writeln()
      ..writeln('Top fixes:');
    for (var i = 0; i < fixes.length; i++) {
      b.writeln('${i + 1}. ${_s(fixes[i]['title'])}');
    }
  }
  b
    ..writeln()
    ..writeln(_shortDisclaimer);
  return b.toString().trimRight();
}

/// The complete report as plain text (every section), for a .txt download.
String reportFullText(Report r, {String? projectName}) {
  final b = StringBuffer()..writeln('VIRALFORGE - VIRAL READINESS REPORT');
  final meta = _meta(r, projectName);
  if (meta.isNotEmpty) b.writeln(meta.join(' | '));
  final when = formatDateTime(r.generatedAt);
  if (when.isNotEmpty) b.writeln('Generated $when${r.model.isEmpty ? '' : ' with ${r.model}'}');
  b
    ..writeln()
    ..writeln('SCORES')
    ..writeln('Overall: ${r.overall}/100 (${_verdict(r)})');
  for (final e in _scoreLabels) {
    b.writeln('${e.$2}: ${r.scores[e.$1] ?? 0}/100');
  }
  if (r.summary.isNotEmpty) {
    b
      ..writeln()
      ..writeln('WHAT THE AI SAW')
      ..writeln(r.summary);
  }
  if (r.recommendations.isNotEmpty) {
    b
      ..writeln()
      ..writeln('FIXES, IN ORDER');
    for (final x in r.recommendations) {
      b.writeln('${_s(x['priority'])}. ${_s(x['title'])} (expected impact: ${_s(x['expected_impact'])})');
      if (_s(x['detail']).isNotEmpty) b.writeln('   ${_s(x['detail'])}');
    }
  }
  if (r.strengths.isNotEmpty) {
    b
      ..writeln()
      ..writeln('WORKING WELL');
    for (final s in r.strengths) {
      b.writeln('- $s');
    }
  }
  if (r.weaknesses.isNotEmpty) {
    b
      ..writeln()
      ..writeln('HOLDING IT BACK');
    for (final s in r.weaknesses) {
      b.writeln('- $s');
    }
  }
  final p = r.personas;
  if (p.items.isNotEmpty) {
    b
      ..writeln()
      ..writeln('HOW TEN VIEWERS REACTED (${p.label})');
    for (final x in p.items) {
      if (x['status'] != 'ok') {
        b.writeln('- ${_s(x['name'])}: no reaction was generated.');
        continue;
      }
      b.writeln('- ${_s(x['name'])}: interest ${_s(x['interest_level'])}/10, '
          '${_actionLabels[_s(x['likely_action'])] ?? _s(x['likely_action'])}, '
          '${x['would_finish'] == true ? 'watches to the end' : 'likely to drop off'}');
      b.writeln('  ${_s(x['reaction'])}');
      if (_s(x['concern']).isNotEmpty) b.writeln('  Concern: ${_s(x['concern'])}');
    }
  }
  if (r.dimensions.isNotEmpty) {
    b
      ..writeln()
      ..writeln('THE SEVEN RATINGS');
    for (final d in r.dimensions) {
      b.writeln('- ${_s(d['label'])}: ${_s(d['score'])}/10. ${_s(d['rationale'])}');
    }
  }
  if (r.observations.isNotEmpty) {
    b
      ..writeln()
      ..writeln('MOMENTS IN THE VIDEO');
    for (final o in r.observations) {
      b.writeln('- ${_areaLabels[_s(o['area'])] ?? _s(o['area'])} (${_s(o['evidence'])}): ${_s(o['observation'])}');
    }
  }
  b.writeln();
  if (r.confidence.isNotEmpty) b.writeln('AI confidence: ${r.confidence}. ${r.confidenceNote}');
  b.writeln(r.disclaimer.isEmpty ? _shortDisclaimer : r.disclaimer);
  return b.toString().trimRight();
}

String escapeHtml(String s) => s
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&#39;');

String _e(Object? v) => escapeHtml(_s(v));

/// A self-contained HTML page (no scripts, no external files) that opens in any browser and prints
/// cleanly to PDF. With [autoPrint] it opens the print dialog as soon as it loads.
String reportHtml(Report r, {String? projectName, bool autoPrint = false}) {
  final meta = _meta(r, projectName).map(escapeHtml).join(' &middot; ');
  final when = formatDateTime(r.generatedAt);
  final b = StringBuffer()
    ..writeln('<!doctype html><html lang="en"><head><meta charset="utf-8">')
    ..writeln('<meta name="viewport" content="width=device-width,initial-scale=1">')
    ..writeln('<title>ViralForge report${projectName == null || projectName.trim().isEmpty ? '' : ' - ${_e(projectName)}'}</title>')
    ..writeln('<style>$_css</style></head><body><main>')
    ..writeln('<p class="brand">ViralForge</p><h1>Viral Readiness Report</h1>');
  if (meta.isNotEmpty) b.writeln('<p class="meta">$meta</p>');
  if (when.isNotEmpty) b.writeln('<p class="meta">Generated ${_e(when)}${r.model.isEmpty ? '' : ' with ${_e(r.model)}'}</p>');

  b.writeln('<section class="overall"><div class="big">${r.overall}<span>/100</span></div>'
      '<div><div class="verdict">${_e(_verdict(r))}</div><div class="help">${_e(verdictHelp(r.overall))}</div></div></section>');
  b.writeln('<div class="cards">');
  for (final e in _scoreLabels) {
    b.writeln('<div class="card"><div class="n">${r.scores[e.$1] ?? 0}</div><div class="l">${e.$2}</div></div>');
  }
  b.writeln('</div>');

  if (r.summary.isNotEmpty) b.writeln('<h2>What the AI saw</h2><p>${_e(r.summary)}</p>');

  if (r.recommendations.isNotEmpty) {
    b.writeln('<h2>Fixes, in order</h2><ol class="fixes">');
    for (final x in r.recommendations) {
      b.writeln('<li><strong>${_e(x['title'])}</strong> <em>(expected impact: ${_e(x['expected_impact'])})</em>'
          '<br>${_e(x['detail'])}</li>');
    }
    b.writeln('</ol>');
  }

  if (r.strengths.isNotEmpty || r.weaknesses.isNotEmpty) {
    b.writeln('<div class="two">');
    b.writeln('<div><h2>Working well</h2><ul>${r.strengths.map((s) => '<li>${escapeHtml(s)}</li>').join()}</ul></div>');
    b.writeln('<div><h2>Holding it back</h2><ul>${r.weaknesses.map((s) => '<li>${escapeHtml(s)}</li>').join()}</ul></div>');
    b.writeln('</div>');
  }

  final p = r.personas;
  if (p.items.isNotEmpty) {
    b.writeln('<h2>How ten viewers reacted</h2><p class="note">${_e(p.label)}</p>');
    for (final x in p.items) {
      if (x['status'] != 'ok') {
        b.writeln('<div class="persona"><strong>${_e(x['name'])}</strong><br><em>No reaction was generated.</em></div>');
        continue;
      }
      b.writeln('<div class="persona"><strong>${_e(x['name'])}</strong> <span class="tag">${_e(x['description'])}</span><br>'
          'Interest ${_e(x['interest_level'])}/10 &middot; ${_e(_actionLabels[_s(x['likely_action'])] ?? x['likely_action'])} &middot; '
          '${x['would_finish'] == true ? 'Watches to the end' : 'Likely to drop off'}<br>'
          '${_e(x['reaction'])}<br><span class="tag">Concern: ${_e(x['concern'])}</span></div>');
    }
  }

  if (r.dimensions.isNotEmpty) {
    b.writeln('<h2>The seven ratings</h2><table><tr><th>Dimension</th><th>Score</th><th>Why</th></tr>');
    for (final d in r.dimensions) {
      b.writeln('<tr><td>${_e(d['label'])}</td><td>${_e(d['score'])}/10</td><td>${_e(d['rationale'])}</td></tr>');
    }
    b.writeln('</table>');
  }

  if (r.observations.isNotEmpty) {
    b.writeln('<h2>Moments in the video</h2><ul>');
    for (final o in r.observations) {
      b.writeln('<li><strong>${_e(_areaLabels[_s(o['area'])] ?? o['area'])}</strong> (${_e(o['evidence'])}): ${_e(o['observation'])}</li>');
    }
    b.writeln('</ul>');
  }

  if (r.confidence.isNotEmpty) {
    b.writeln('<p><strong>AI confidence: ${_e(r.confidence)}.</strong> ${_e(r.confidenceNote)}</p>');
  }
  b.writeln('<p class="disclaimer">${_e(r.disclaimer.isEmpty ? _shortDisclaimer : r.disclaimer)}</p>');
  b.writeln('</main>');
  if (autoPrint) b.writeln('<script>window.addEventListener("load",function(){setTimeout(function(){window.print()},300)})</script>');
  b.writeln('</body></html>');
  return b.toString();
}

/// "viralforge-report-spring-recipes-2026-03-02.<ext>" - safe for every operating system.
String reportFileName(Report r, {String? projectName, required String ext}) {
  final slug = (projectName ?? '')
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  final d = DateTime.tryParse(r.generatedAt)?.toLocal();
  final date = d == null
      ? ''
      : '-${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  final short = slug.length > 40 ? slug.substring(0, 40) : slug;
  return 'viralforge-report${short.isEmpty ? '' : '-$short'}$date.$ext';
}

const _css = '''
*{box-sizing:border-box}body{margin:0;background:#f4f6fb;color:#1f2937;font:16px/1.55 system-ui,-apple-system,"Segoe UI",Roboto,Arial,sans-serif}
main{max-width:820px;margin:0 auto;padding:32px 20px 48px;background:#fff}
.brand{margin:0;color:#2563eb;font-weight:700;letter-spacing:.04em;text-transform:uppercase;font-size:13px}
h1{margin:4px 0 6px;font-size:28px;color:#16294d}h2{margin:28px 0 8px;font-size:18px;color:#16294d;border-bottom:1px solid #e5e7eb;padding-bottom:4px}
.meta{margin:0;color:#5b6577;font-size:14px}
.overall{display:flex;gap:18px;align-items:center;margin:22px 0 12px;padding:16px 20px;border:1px solid #dbe4f8;border-radius:14px;background:#eef3fe}
.big{font-size:54px;font-weight:800;color:#2563eb;line-height:1}.big span{font-size:18px;color:#5b6577;font-weight:600}
.verdict{font-size:22px;font-weight:700;color:#16294d}.help{color:#5b6577}
.cards{display:grid;grid-template-columns:repeat(4,1fr);gap:10px}.card{border:1px solid #e5e7eb;border-radius:12px;padding:10px;text-align:center}
.card .n{font-size:26px;font-weight:800;color:#2563eb}.card .l{font-size:13px;color:#5b6577}
.two{display:grid;grid-template-columns:1fr 1fr;gap:20px}.fixes li{margin-bottom:10px}
.persona{border:1px solid #e5e7eb;border-radius:12px;padding:10px 14px;margin:8px 0;break-inside:avoid}.tag{color:#5b6577;font-size:14px}
table{width:100%;border-collapse:collapse;font-size:14px}th,td{border:1px solid #e5e7eb;padding:6px 8px;text-align:left;vertical-align:top}th{background:#f3f4f6}
.note{color:#5b6577;font-style:italic}.disclaimer{margin-top:24px;padding:10px 14px;border-radius:10px;background:#fff7e0;border:1px solid #f1d98a;font-size:14px}
@media(max-width:560px){.cards{grid-template-columns:repeat(2,1fr)}.two{grid-template-columns:1fr}}
@media print{body{background:#fff}main{padding:0;max-width:none}h2{break-after:avoid}.overall,.card,table,.disclaimer{break-inside:avoid}}
''';
