import 'package:flutter/material.dart';

import '../models.dart';
import '../theme.dart';
import '../util/format.dart';
import 'common.dart';
import 'frame_strip.dart';
import 'fx.dart';

const _scoreRows = <(String, String)>[
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

class ReportView extends StatelessWidget {
  final Report report;
  final Job job;
  const ReportView({super.key, required this.report, required this.job});

  @override
  Widget build(BuildContext context) {
    final scores = report.scores;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _VerdictBand(report: report),
      const SizedBox(height: 16),
      Reveal(
        delayMs: 200,
        child: Panel(
          child: Column(children: [
            for (var i = 0; i < _scoreRows.length; i++) ...[
              if (i > 0) const Padding(padding: EdgeInsets.symmetric(vertical: 14), child: Divider()),
              _ScoreRow(
                label: _scoreRows[i].$2,
                score: scores[_scoreRows[i].$1] ?? 0,
                formula: report.formulas[_scoreRows[i].$1] ?? '',
              ),
            ],
          ]),
        ),
      ),
      const SizedBox(height: 12),
      _Rubric(report: report),
      const SectionTitle('What the AI saw'),
      Reveal(child: Panel(child: Text(report.summary, style: const TextStyle(height: 1.55, fontSize: 15)))),
      const SectionTitle('Strengths and weaknesses'),
      LayoutBuilder(builder: (context, c) {
        final two = c.maxWidth > 720;
        final good = _BulletPanel(title: 'Working well', items: report.strengths, color: Tk.good, icon: Icons.check_circle_outline);
        final bad = _BulletPanel(title: 'Holding it back', items: report.weaknesses, color: Tk.bad, icon: Icons.remove_circle_outline);
        return two
            ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: good), const SizedBox(width: 16), Expanded(child: bad)])
            : Column(children: [good, const SizedBox(height: 12), bad]);
      }),
      const SectionTitle('What to change first'),
      Reveal(child: _Recommendations(items: report.recommendations)),
      const SectionTitle('Seven ratings behind the scores'),
      _Dimensions(items: report.dimensions),
      if (report.observations.isNotEmpty) ...[
        const SectionTitle('Craft notes'),
        _Observations(items: report.observations),
      ],
      const SectionTitle('Simulated audience'),
      _PersonasSection(personas: report.personas),
      const SizedBox(height: 28),
      _Footer(report: report),
    ]);
  }
}

class _VerdictBand extends StatelessWidget {
  final Report report;
  const _VerdictBand({required this.report});

  @override
  Widget build(BuildContext context) {
    final meta = [platformLabel(report.platform), report.niche, if (report.inputType == 'script') 'script only'].where((e) => e.isNotEmpty).join(', ');
    final band = Panel(
      color: Tk.ink,
      borderColor: Tk.ink,
      padding: const EdgeInsets.all(28),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Viral Readiness', style: const TextStyle(color: Color(0xFFC3CAE0), fontSize: 15, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Semantics(
            label: 'Overall score ${report.overall} out of 100',
            child: ExcludeSemantics(
              child: CountUp(value: report.overall, style: display(96, color: Colors.white, height: 0.95, spacing: -3)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 8, bottom: 10),
            child: Text('/ 100', style: display(24, color: const Color(0xFF9AA5C8), weight: FontWeight.w500)),
          ),
          const Spacer(),
          Flexible(child: Text(report.verdict, textAlign: TextAlign.right, style: display(26, color: Tk.sodium))),
        ]),
        const SizedBox(height: 18),
        FrameStrip(value: report.overall.toDouble(), height: 26, trackColor: const Color(0xFF2A3560), semanticLabel: 'Overall score meter'),
        const SizedBox(height: 14),
        Text(meta, style: const TextStyle(color: Color(0xFFC3CAE0), fontSize: 14)),
      ]),
    );
    return Stack(children: [
      band,
      if (Fx.enabled && report.overall >= 60)
        Positioned.fill(
          child: IgnorePointer(
            child: ClipRRect(borderRadius: BorderRadius.circular(Tk.radius), child: const ConfettiBurst()),
          ),
        ),
    ]);
  }
}

class _ScoreRow extends StatelessWidget {
  final String label;
  final int score;
  final String formula;
  const _ScoreRow({required this.label, required this.score, required this.formula});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final wide = c.maxWidth > 640;
      final labelBlock = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: display(20, weight: FontWeight.w600)),
        if (formula.isNotEmpty) Text(formula, style: const TextStyle(color: Tk.mute, fontSize: 12.5, height: 1.35)),
      ]);
      final numText = Text('$score', style: display(32, height: 1));
      final strip = FrameStrip(value: score.toDouble(), height: 18, semanticLabel: '$label score $score out of 100');
      if (wide) {
        return Row(children: [
          SizedBox(width: 250, child: labelBlock),
          const SizedBox(width: 20),
          Expanded(child: strip),
          const SizedBox(width: 20),
          SizedBox(width: 48, child: Align(alignment: Alignment.centerRight, child: numText)),
        ]);
      }
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Expanded(child: labelBlock), numText]),
        const SizedBox(height: 10),
        strip,
      ]);
    });
  }
}

class _Rubric extends StatelessWidget {
  final Report report;
  const _Rubric({required this.report});

  @override
  Widget build(BuildContext context) {
    final rubric = report.rubric;
    final dims = ((rubric['dimensions'] as List?) ?? const []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    final f = report.formulas;
    return Panel(
      padding: EdgeInsets.zero,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          title: Text('How these scores are calculated', style: display(18, weight: FontWeight.w600)),
          children: [
            Text(
              'The AI rates seven qualities from 1 to 10. The app, not the AI, turns those ratings into the five scores below (0 to 100). ${rubric['dimension_anchor'] ?? ''}',
              style: const TextStyle(height: 1.5),
            ),
            const SizedBox(height: 12),
            for (final e in f.entries)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Text.rich(TextSpan(children: [
                  TextSpan(text: '${e.key[0].toUpperCase()}${e.key.substring(1)}: ', style: const TextStyle(fontWeight: FontWeight.w700)),
                  TextSpan(text: e.value),
                ])),
              ),
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text('Rounding: ${rubric['rounding'] ?? 'half up'}.', style: const TextStyle(color: Tk.mute)),
            ),
            const SizedBox(height: 12),
            for (final d in dims)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Text.rich(TextSpan(children: [
                  TextSpan(text: '${d['label']}: ', style: const TextStyle(fontWeight: FontWeight.w700)),
                  TextSpan(text: '${d['definition']}', style: const TextStyle(color: Tk.mute)),
                ])),
              ),
          ],
        ),
      ),
    );
  }
}

class _BulletPanel extends StatelessWidget {
  final String title;
  final List<String> items;
  final Color color;
  final IconData icon;
  const _BulletPanel({required this.title, required this.items, required this.color, required this.icon});

  @override
  Widget build(BuildContext context) => Panel(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: display(18, weight: FontWeight.w600)),
          const SizedBox(height: 10),
          for (final s in items)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(icon, size: 18, color: color),
                const SizedBox(width: 10),
                Expanded(child: Text(s, style: const TextStyle(height: 1.45))),
              ]),
            ),
        ]),
      );
}

class _Recommendations extends StatelessWidget {
  final List<Map<String, dynamic>> items;
  const _Recommendations({required this.items});

  @override
  Widget build(BuildContext context) {
    const impact = {'high': 'High impact', 'medium': 'Medium impact', 'low': 'Low impact'};
    return Panel(
      padding: EdgeInsets.zero,
      child: Column(children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const Divider(),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: i == 0 ? Tk.sodium : Tk.ultraSoft, borderRadius: BorderRadius.circular(8)),
                child: Text('${items[i]['priority']}', style: display(16)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Wrap(spacing: 10, crossAxisAlignment: WrapCrossAlignment.center, children: [
                    Text('${items[i]['title']}', style: display(17, weight: FontWeight.w600)),
                    Text(impact['${items[i]['expected_impact']}'] ?? '', style: const TextStyle(color: Tk.mute, fontSize: 12.5, fontWeight: FontWeight.w600)),
                  ]),
                  const SizedBox(height: 4),
                  Text('${items[i]['detail']}', style: const TextStyle(height: 1.5)),
                ]),
              ),
            ]),
          ),
        ],
      ]),
    );
  }
}

class _Dimensions extends StatelessWidget {
  final List<Map<String, dynamic>> items;
  const _Dimensions({required this.items});

  @override
  Widget build(BuildContext context) => Panel(
        padding: EdgeInsets.zero,
        child: Column(children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) const Divider(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text('${items[i]['label']}', style: const TextStyle(fontWeight: FontWeight.w700))),
                  SizedBox(width: 90, child: FrameStrip(value: ((items[i]['score'] as num) * 10).toDouble(), cells: 10, height: 10, animate: false, semanticLabel: '${items[i]['label']} ${items[i]['score']} out of 10')),
                  SizedBox(width: 52, child: Text('${items[i]['score']}/10', textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w700))),
                ]),
                const SizedBox(height: 4),
                Text('${items[i]['rationale']}', style: const TextStyle(color: Tk.mute, height: 1.45)),
              ]),
            ),
          ],
        ]),
      );
}

class _Observations extends StatelessWidget {
  final List<Map<String, dynamic>> items;
  const _Observations({required this.items});

  @override
  Widget build(BuildContext context) => Panel(
        child: Column(children: [
          for (final o in items)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                SizedBox(width: 150, child: Text(_areaLabels['${o['area']}'] ?? '${o['area']}', style: const TextStyle(fontWeight: FontWeight.w700))),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${o['observation']}', style: const TextStyle(height: 1.45)),
                    if ('${o['evidence']}'.isNotEmpty) Text('${o['evidence']}', style: const TextStyle(color: Tk.mute, fontSize: 13)),
                  ]),
                ),
              ]),
            ),
        ]),
      );
}

class _PersonasSection extends StatelessWidget {
  final Personas personas;
  const _PersonasSection({required this.personas});

  @override
  Widget build(BuildContext context) {
    final status = personas.status;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      InlineMessage(MsgKind.info, personas.label),
      if (status != 'complete') ...[
        const SizedBox(height: 10),
        InlineMessage(
          status == 'failed' ? MsgKind.error : MsgKind.warn,
          personas.note ?? '${personas.received} of ${personas.expected} persona reactions were produced.',
        ),
      ],
      const SizedBox(height: 14),
      LayoutBuilder(builder: (context, c) {
        final cols = c.maxWidth > 760 ? 2 : 1;
        final w = (c.maxWidth - (cols - 1) * 14) / cols;
        return Wrap(spacing: 14, runSpacing: 14, children: [
          for (final p in personas.items) SizedBox(width: w, child: HoverLift(child: _PersonaCard(p))),
        ]);
      }),
    ]);
  }
}

class _PersonaCard extends StatelessWidget {
  final Map<String, dynamic> p;
  const _PersonaCard(this.p);

  @override
  Widget build(BuildContext context) {
    final ok = p['status'] == 'ok';
    return Panel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('${p['name']}', style: display(18, weight: FontWeight.w600)),
        Text('${p['description']}', style: const TextStyle(color: Tk.mute, fontSize: 13, height: 1.4)),
        const SizedBox(height: 12),
        if (!ok)
          const Text('No reaction was generated for this persona.', style: TextStyle(color: Tk.mute, fontStyle: FontStyle.italic))
        else ...[
          Wrap(spacing: 14, runSpacing: 4, children: [
            Text('Interest ${p['interest_level']}/10', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            Text(_actionLabels['${p['likely_action']}'] ?? '${p['likely_action']}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            Text(p['would_finish'] == true ? 'Watches to the end' : 'Likely to drop off', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
          ]),
          const SizedBox(height: 8),
          Text('${p['reaction']}', style: const TextStyle(height: 1.5)),
          const SizedBox(height: 8),
          Text('Concern: ${p['concern']}', style: const TextStyle(color: Tk.mute, height: 1.45, fontSize: 14)),
        ],
      ]),
    );
  }
}

class _Footer extends StatelessWidget {
  final Report report;
  const _Footer({required this.report});

  @override
  Widget build(BuildContext context) {
    final conf = report.confidence.isEmpty ? '' : '${report.confidence[0].toUpperCase()}${report.confidence.substring(1)}';
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (conf.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Text.rich(TextSpan(children: [
            TextSpan(text: 'AI confidence: $conf. ', style: const TextStyle(fontWeight: FontWeight.w700)),
            TextSpan(text: report.confidenceNote),
          ])),
        ),
      InlineMessage(MsgKind.warn, report.disclaimer),
      const SizedBox(height: 10),
      Text('Generated ${formatDateTime(report.generatedAt)} with ${report.model}.', style: const TextStyle(color: Tk.mute, fontSize: 12.5)),
    ]);
  }
}