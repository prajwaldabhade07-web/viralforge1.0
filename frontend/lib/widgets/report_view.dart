import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import '../models.dart';
import '../theme.dart';
import '../util/evidence.dart';
import '../util/format.dart';
import '../util/platform.dart';
import 'common.dart';
import 'film.dart';
import 'frame_strip.dart';
import 'fx.dart';
import 'report_player.dart';

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

/// The screening room: reveal, video, sticky tabs, notes and the ten-seat cinema.
class ReportView extends StatefulWidget {
  final Report report;
  final Job job;
  final Widget header;
  const ReportView({super.key, required this.report, required this.job, required this.header});

  @override
  State<ReportView> createState() => _ReportViewState();
}

class _ReportViewState extends State<ReportView> {
  final _scroll = ScrollController();
  final _seek = ReportSeek();
  final _tab = ValueNotifier<int>(0);
  final _keys = List<GlobalKey>.generate(4, (_) => GlobalKey());

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll.dispose();
    _tab.dispose();
    super.dispose();
  }

  double? _revealOffset(int i) {
    final ctx = _keys[i].currentContext;
    final box = ctx?.findRenderObject();
    if (box == null || !box.attached) return null;
    final viewport = RenderAbstractViewport.maybeOf(box);
    return viewport?.getOffsetToReveal(box, 0.0).offset;
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    var best = 0;
    for (var i = 0; i < _keys.length; i++) {
      final off = _revealOffset(i);
      if (off != null && off - 72 <= _scroll.offset + 4) best = i;
    }
    if (best != _tab.value) _tab.value = best;
  }

  void _goTo(int i) {
    final off = _revealOffset(i);
    if (off == null || !_scroll.hasClients) return;
    final target = (off - 72).clamp(0.0, _scroll.position.maxScrollExtent).toDouble();
    _scroll.animateTo(target, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    _tab.value = i;
  }

  Future<void> _showVideoAt(double seconds) async {
    if (_scroll.hasClients) {
      await _scroll.animateTo(0, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    }
    await _seek.seek(seconds);
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.report;
    final job = widget.job;
    final scores = r.scores;
    final narrow = MediaQuery.of(context).size.width < 700;
    final pad = narrow ? 16.0 : 32.0;
    final hasVideo = job.videoId != null && r.inputType == 'video';
    final markers = <PlayerMarker>[
      for (final o in r.observations)
        if (parseEvidenceSeconds('${o['evidence']}') != null)
          PlayerMarker(parseEvidenceSeconds('${o['evidence']}')!, _areaLabels['${o['area']}'] ?? '${o['area']}'),
    ];

    Widget framed(Widget child, {double top = 0, double bottom = 0}) => Padding(
          padding: EdgeInsets.fromLTRB(pad, top, pad, bottom),
          child: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 1040), child: child)),
        );

    return CustomScrollView(
      controller: _scroll,
      slivers: [
        SliverToBoxAdapter(
          child: framed(
            top: pad,
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              widget.header,
              _ScoreBand(report: r, jobId: job.id),
              if (hasVideo) ...[
                const SizedBox(height: 16),
                ReportPlayer(videoId: job.videoId!, markers: markers, seek: _seek),
              ],
            ]),
          ),
        ),
        SliverPersistentHeader(pinned: true, delegate: _TabsDelegate(report: r, tab: _tab, onTap: _goTo, pad: pad)),
        SliverToBoxAdapter(
          child: framed(
            bottom: 48,
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              KeyedSubtree(
                key: _keys[0],
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const SizedBox(height: 16),
                  Panel(
                    child: Column(children: [
                      for (var i = 0; i < _scoreRows.length; i++) ...[
                        if (i > 0) const Padding(padding: EdgeInsets.symmetric(vertical: 14), child: Divider()),
                        _ScoreRow(
                          label: _scoreRows[i].$2,
                          score: scores[_scoreRows[i].$1] ?? 0,
                          formula: r.formulas[_scoreRows[i].$1] ?? '',
                        ),
                      ],
                    ]),
                  ),
                  const SizedBox(height: 12),
                  _Rubric(report: r),
                  const SectionTitle('What Pip saw'),
                  Panel(child: Text(r.summary, style: context.ty.body)),
                ]),
              ),
              KeyedSubtree(
                key: _keys[1],
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const SectionTitle("What's costing you views"),
                  _Notes(items: r.recommendations),
                  const SectionTitle('Strengths and weaknesses'),
                  LayoutBuilder(builder: (context, c) {
                    final p = context.pal;
                    final two = c.maxWidth > 720;
                    final good = _BulletPanel(title: 'Working well', items: r.strengths, color: p.good, icon: Icons.check_circle_outline);
                    final bad = _BulletPanel(title: 'Holding it back', items: r.weaknesses, color: p.bad, icon: Icons.remove_circle_outline);
                    return two
                        ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: good), const SizedBox(width: 16), Expanded(child: bad)])
                        : Column(children: [good, const SizedBox(height: 12), bad]);
                  }),
                ]),
              ),
              KeyedSubtree(
                key: _keys[2],
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const SectionTitle('The screening room'),
                  _PersonasSection(personas: r.personas),
                ]),
              ),
              KeyedSubtree(
                key: _keys[3],
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const SectionTitle('The seven ratings'),
                  _Dimensions(items: r.dimensions),
                  if (r.observations.isNotEmpty) ...[
                    const SectionTitle('Craft notes'),
                    _Observations(items: r.observations, canSeek: hasVideo, onSeek: _showVideoAt),
                  ],
                  const SizedBox(height: 28),
                  _Footer(report: r),
                ]),
              ),
            ]),
          ),
        ),
      ],
    );
  }
}

class _TabsDelegate extends SliverPersistentHeaderDelegate {
  final Report report;
  final ValueNotifier<int> tab;
  final ValueChanged<int> onTap;
  final double pad;
  const _TabsDelegate({required this.report, required this.tab, required this.onTap, required this.pad});

  static const labels = ['Scores', 'Fixes', 'Screening room', 'Details'];

  @override
  double get minExtent => 60;

  @override
  double get maxExtent => 60;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    final p = context.pal;
    return Container(
      color: p.bg,
      padding: EdgeInsets.symmetric(horizontal: pad),
      alignment: Alignment.center,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1040),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(color: p.ultraSoft, borderRadius: BorderRadius.circular(20)),
            child: Text('Overall ${report.overall}/100', style: TextStyle(color: p.ultra, fontWeight: FontWeight.w700, fontSize: 13)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ValueListenableBuilder<int>(
                valueListenable: tab,
                builder: (context, v, _) => Row(children: [
                  for (var i = 0; i < labels.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(label: Text(labels[i]), selected: v == i, onSelected: (_) => onTap(i)),
                    ),
                ]),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _TabsDelegate old) => old.report != report || old.pad != pad;
}

// ───────────────────────── Score reveal ─────────────────────────

class _ScoreBand extends StatefulWidget {
  final Report report;
  final String jobId;
  const _ScoreBand({required this.report, required this.jobId});

  @override
  State<_ScoreBand> createState() => _ScoreBandState();
}

class _ScoreBandState extends State<_ScoreBand> with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  bool _play = false;

  String get _seenKey => 'vf_seen_${widget.jobId}';

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
    _play = Fx.enabled && readPref(_seenKey) != '1';
    if (_play) {
      _c.addStatusListener((s) {
        if (s == AnimationStatus.completed) writePref(_seenKey, '1');
      });
      _c.forward();
    } else {
      _c.value = 1;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_play && (MediaQuery.maybeOf(context)?.disableAnimations ?? false)) {
      _play = false;
      _c.value = 1;
      writePref(_seenKey, '1');
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final ty = context.ty;
    final r = widget.report;
    final narrow = MediaQuery.of(context).size.width < 700;
    final meta = [platformLabel(r.platform), r.niche, if (r.inputType == 'script') 'script only'].where((e) => e.isNotEmpty).join(', ');
    // A Listener (not a GestureDetector) so tap-to-skip adds no accessibility node
    // and the score's own label stays readable on its own.
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) {
        if (_c.isAnimating) _c.value = 1;
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(kRadius),
        child: Container(
          width: double.infinity,
          color: p.hero,
          child: Stack(children: [
            GrainOverlay(color: p.onHero.withValues(alpha: 0.05)),
            Padding(
              padding: const EdgeInsets.all(28),
              child: AnimatedBuilder(
                animation: _c,
                builder: (context, _) {
                  final e = Curves.easeOutCubic.transform(_c.value);
                  final shown = (r.overall * e).round();
                  final vt = ((_c.value - 0.55) / 0.45).clamp(0.0, 1.0).toDouble();
                  final spring = Curves.elasticOut.transform(vt);
                  return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Text('Viral Readiness', style: TextStyle(color: p.heroMute, fontSize: 15, fontWeight: FontWeight.w600)),
                      const Spacer(),
                      if (_c.isAnimating) Text('Tap to skip', style: TextStyle(color: p.heroMute, fontSize: 12.5)),
                    ]),
                    const SizedBox(height: 4),
                    Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Semantics(
                        label: 'Overall score ${r.overall} out of 100',
                        child: ExcludeSemantics(
                          child: Text('$shown', style: ty.score.copyWith(color: p.onHero, fontSize: narrow ? 72 : 96)),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(left: 8, bottom: 10),
                        child: Text('/ 100', style: ty.title.copyWith(color: p.heroMute, fontWeight: FontWeight.w500)),
                      ),
                      const Spacer(),
                      Flexible(
                        child: Opacity(
                          opacity: vt,
                          child: Transform.scale(
                            scale: 0.8 + 0.2 * spring,
                            alignment: Alignment.centerRight,
                            child: Text(r.verdict, textAlign: TextAlign.right, style: ty.title.copyWith(color: p.sodium)),
                          ),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 18),
                    FrameStrip(
                      value: r.overall * e,
                      height: 26,
                      animate: false,
                      perforated: true,
                      trackColor: p.heroTrack,
                      semanticLabel: 'Overall score meter',
                    ),
                    const SizedBox(height: 14),
                    Text(meta, style: TextStyle(color: p.heroMute, fontSize: 14)),
                  ]);
                },
              ),
            ),
            if (_play && r.overall >= 75) const Positioned.fill(child: IgnorePointer(child: ConfettiBurst())),
          ]),
        ),
      ),
    );
  }
}

// ───────────────────────── Scores ─────────────────────────

class _ScoreRow extends StatelessWidget {
  final String label;
  final int score;
  final String formula;
  const _ScoreRow({required this.label, required this.score, required this.formula});

  @override
  Widget build(BuildContext context) {
    final ty = context.ty;
    return LayoutBuilder(builder: (context, c) {
      final wide = c.maxWidth > 640;
      final labelBlock = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: ty.heading.copyWith(fontSize: 20)),
        if (formula.isNotEmpty) Text(formula, style: ty.caption.copyWith(fontSize: 12.5)),
      ]);
      final numText = Text('$score', style: ty.title.copyWith(fontSize: 32, height: 1));
      final strip = FrameStrip(value: score.toDouble(), height: 18, animate: false, semanticLabel: '$label score $score out of 100');
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
    final p = context.pal;
    final ty = context.ty;
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
          title: Text('How these scores are calculated', style: ty.heading),
          children: [
            Text(
              'The AI rates seven qualities from 1 to 10. The app, not the AI, turns those ratings into the five scores below (0 to 100). ${rubric['dimension_anchor'] ?? ''}',
              style: ty.body,
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
              child: Text('Rounding: ${rubric['rounding'] ?? 'half up'}.', style: TextStyle(color: p.mute)),
            ),
            const SizedBox(height: 12),
            for (final d in dims)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Text.rich(TextSpan(children: [
                  TextSpan(text: '${d['label']}: ', style: const TextStyle(fontWeight: FontWeight.w700)),
                  TextSpan(text: '${d['definition']}', style: TextStyle(color: p.mute)),
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
          Text(title, style: context.ty.heading),
          const SizedBox(height: 10),
          for (final s in items)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(icon, size: 18, color: color),
                const SizedBox(width: 10),
                Expanded(child: Text(s, style: context.ty.body)),
              ]),
            ),
        ]),
      );
}

// ───────────────────────── Director's notes ─────────────────────────

class _Notes extends StatefulWidget {
  final List<Map<String, dynamic>> items;
  const _Notes({required this.items});

  @override
  State<_Notes> createState() => _NotesState();
}

class _NotesState extends State<_Notes> {
  final Set<int> _done = {};

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final ty = context.ty;
    const impact = {'high': 'High impact', 'medium': 'Medium impact', 'low': 'Low impact'};
    final items = widget.items;
    return Column(children: [
      for (var i = 0; i < items.length; i++)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Panel(
            padding: const EdgeInsets.fromLTRB(18, 16, 8, 16),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: i == 0 ? p.sodium : p.ultraSoft, borderRadius: BorderRadius.circular(8)),
                child: Text('${items[i]['priority']}', style: ty.heading.copyWith(color: i == 0 ? p.onSodium : p.ultra)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Opacity(
                  opacity: _done.contains(i) ? 0.55 : 1,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Wrap(spacing: 10, crossAxisAlignment: WrapCrossAlignment.center, children: [
                      Text('${items[i]['title']}',
                          style: ty.heading.copyWith(decoration: _done.contains(i) ? TextDecoration.lineThrough : null)),
                      Text(impact['${items[i]['expected_impact']}'] ?? '', style: ty.caption.copyWith(fontWeight: FontWeight.w600)),
                    ]),
                    const SizedBox(height: 4),
                    Text('${items[i]['detail']}', style: ty.body),
                  ]),
                ),
              ),
              Column(children: [
                IconButton(
                  tooltip: _done.contains(i) ? 'Mark as not done' : 'Mark as done',
                  icon: Icon(_done.contains(i) ? Icons.check_circle : Icons.radio_button_unchecked, color: _done.contains(i) ? p.good : p.mute),
                  onPressed: () => setState(() => _done.contains(i) ? _done.remove(i) : _done.add(i)),
                ),
                IconButton(
                  tooltip: 'Copy this note',
                  icon: Icon(Icons.copy_outlined, color: p.mute, size: 20),
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: '${items[i]['title']}\n${items[i]['detail']}'));
                    if (context.mounted) toast(context, 'Copied to your clipboard.');
                  },
                ),
              ]),
            ]),
          ),
        ),
    ]);
  }
}

// ───────────────────────── Details ─────────────────────────

class _Dimensions extends StatelessWidget {
  final List<Map<String, dynamic>> items;
  const _Dimensions({required this.items});

  @override
  Widget build(BuildContext context) {
    final ty = context.ty;
    return Panel(
      padding: EdgeInsets.zero,
      child: Column(children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const Divider(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text('${items[i]['label']}', style: ty.bodyStrong)),
                SizedBox(
                  width: 90,
                  child: FrameStrip(
                    value: ((items[i]['score'] as num) * 10).toDouble(),
                    cells: 10,
                    height: 10,
                    animate: false,
                    semanticLabel: '${items[i]['label']} ${items[i]['score']} out of 10',
                  ),
                ),
                SizedBox(width: 52, child: Text('${items[i]['score']}/10', textAlign: TextAlign.right, style: ty.bodyStrong)),
              ]),
              const SizedBox(height: 4),
              Text('${items[i]['rationale']}', style: ty.body.copyWith(color: context.pal.mute)),
            ]),
          ),
        ],
      ]),
    );
  }
}

class _Observations extends StatelessWidget {
  final List<Map<String, dynamic>> items;
  final bool canSeek;
  final Future<void> Function(double seconds) onSeek;
  const _Observations({required this.items, required this.canSeek, required this.onSeek});

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final ty = context.ty;
    return Panel(
      child: Column(children: [
        for (final o in items)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SizedBox(width: 150, child: Text(_areaLabels['${o['area']}'] ?? '${o['area']}', style: ty.bodyStrong)),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${o['observation']}', style: ty.body),
                  if ('${o['evidence']}'.isNotEmpty) Text('${o['evidence']}', style: ty.caption),
                  if (canSeek && parseEvidenceSeconds('${o['evidence']}') != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: ActionChip(
                        avatar: Icon(Icons.play_arrow, size: 16, color: p.ultra),
                        label: Text('Watch ${formatClock(parseEvidenceSeconds('${o['evidence']}')!)}'),
                        onPressed: () => onSeek(parseEvidenceSeconds('${o['evidence']}')!),
                      ),
                    ),
                ]),
              ),
            ]),
          ),
      ]),
    );
  }
}

// ───────────────────────── Screening room ─────────────────────────

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
      _Cinema(items: personas.items),
      const SizedBox(height: 14),
      LayoutBuilder(builder: (context, c) {
        final cols = c.maxWidth > 760 ? 2 : 1;
        final w = (c.maxWidth - (cols - 1) * 14) / cols;
        return Wrap(spacing: 14, runSpacing: 14, children: [
          for (final p in personas.items) SizedBox(width: w, child: _PersonaCard(p)),
        ]);
      }),
    ]);
  }
}

class _Cinema extends StatefulWidget {
  final List<Map<String, dynamic>> items;
  const _Cinema({required this.items});

  @override
  State<_Cinema> createState() => _CinemaState();
}

class _CinemaState extends State<_Cinema> {
  int? _sel;

  Color _actionColor(Palette p, String a) {
    switch (a) {
      case 'share':
        return p.sodium;
      case 'like':
        return kPink;
      case 'comment':
        return kMint;
      case 'follow':
        return p.ultra;
      default:
        return p.mute;
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final ty = context.ty;
    final items = widget.items;
    String? detail;
    if (_sel != null && _sel! < items.length && items[_sel!]['status'] == 'ok') {
      final it = items[_sel!];
      detail = '${it['name']}: ${_actionLabels['${it['likely_action']}'] ?? it['likely_action']}. '
          '${it['would_finish'] == true ? 'Watches to the end.' : 'Likely to drop off.'}';
    }
    const legend = [('share', 'Share'), ('like', 'Like'), ('comment', 'Comment'), ('follow', 'Follow'), ('keep_scrolling', 'Scroll on')];
    return Panel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Lit seats engaged. Dimmed seats would leave before the end. Tap a seat for details.', style: ty.caption),
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (var i = 0; i < items.length; i++)
            Builder(builder: (context) {
              final it = items[i];
              final ok = it['status'] == 'ok';
              final color = ok ? _actionColor(p, '${it['likely_action']}') : p.track;
              final lit = ok && it['would_finish'] == true;
              return Tooltip(
                message: ok ? (_actionLabels['${it['likely_action']}'] ?? '') : 'No reaction',
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => setState(() => _sel = _sel == i ? null : i),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _sel == i ? p.ultra : Colors.transparent, width: 2),
                    ),
                    child: Icon(Icons.event_seat, size: 28, color: lit ? color : color.withValues(alpha: 0.35)),
                  ),
                ),
              );
            }),
        ]),
        if (detail != null) ...[const SizedBox(height: 10), Text(detail, style: ty.bodyStrong)],
        const SizedBox(height: 12),
        Wrap(spacing: 14, runSpacing: 6, children: [
          for (final l in legend)
            Row(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 10, height: 10, decoration: BoxDecoration(color: _actionColor(p, l.$1), shape: BoxShape.circle)),
              const SizedBox(width: 6),
              Text(l.$2, style: ty.caption),
            ]),
        ]),
      ]),
    );
  }
}

class _PersonaCard extends StatelessWidget {
  final Map<String, dynamic> p;
  const _PersonaCard(this.p);

  @override
  Widget build(BuildContext context) {
    final ty = context.ty;
    final ok = p['status'] == 'ok';
    return Panel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('${p['name']}', style: ty.heading),
        Text('${p['description']}', style: ty.caption),
        const SizedBox(height: 12),
        if (!ok)
          Text('No reaction was generated for this persona.', style: ty.caption.copyWith(fontStyle: FontStyle.italic, fontSize: 14))
        else ...[
          Wrap(spacing: 14, runSpacing: 4, children: [
            Text('Interest ${p['interest_level']}/10', style: ty.bodyStrong.copyWith(fontSize: 13)),
            Text(_actionLabels['${p['likely_action']}'] ?? '${p['likely_action']}', style: ty.bodyStrong.copyWith(fontSize: 13)),
            Text(p['would_finish'] == true ? 'Watches to the end' : 'Likely to drop off', style: ty.bodyStrong.copyWith(fontSize: 13)),
          ]),
          const SizedBox(height: 8),
          Text('${p['reaction']}', style: ty.body),
          const SizedBox(height: 8),
          Text('Concern: ${p['concern']}', style: ty.body.copyWith(color: context.pal.mute, fontSize: 14)),
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
    final ty = context.ty;
    final conf = report.confidence.isEmpty ? '' : '${report.confidence[0].toUpperCase()}${report.confidence.substring(1)}';
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (conf.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Text.rich(TextSpan(style: ty.body, children: [
            TextSpan(text: 'AI confidence: $conf. ', style: const TextStyle(fontWeight: FontWeight.w700)),
            TextSpan(text: report.confidenceNote),
          ])),
        ),
      InlineMessage(MsgKind.warn, report.disclaimer),
      const SizedBox(height: 10),
      Text('Generated ${formatDateTime(report.generatedAt)} with ${report.model}.', style: ty.caption.copyWith(fontSize: 12.5)),
    ]);
  }
}