import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models.dart';
import '../state/providers.dart';
import '../theme.dart';
import '../util/text.dart';
import '../widgets/charts.dart';
import '../widgets/common.dart';
import '../widgets/fx.dart';
import '../widgets/job_row.dart';
import '../widgets/pip.dart';
import 'quick_studio.dart';

const _g = 14.0;

const _tips = [
  'Open on the payoff, then explain. The first two seconds decide everything.',
  'Most people watch with the sound off. Put your key line on screen.',
  'Cut every pause longer than half a second.',
  'End on a reason to rewatch: a loop, a twist, or a question.',
  'One video, one idea. Clear beats clever.',
  'Try three hooks on the same idea and keep the best score.',
  'Relatable beats polished. People share what feels like them.',
];

const _steps = [
  ('Drop your video', 'Pick a short clip, up to 90 seconds.'),
  ('Pip watches it', 'About 1 to 3 minutes. You can leave the page.'),
  ('Read your report', 'Get scores and a list of fixes to try next.'),
];

Widget _in(int ms, Widget w) => Reveal(delayMs: ms, child: w);

/// Equal-height columns on wide screens, a plain stack on narrow ones.
Widget _cols(bool wide, List<(int, Widget)> items) => wide
    ? IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) const SizedBox(width: _g),
            Expanded(flex: items[i].$1, child: items[i].$2),
          ],
        ]),
      )
    : Column(children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(height: _g),
          items[i].$2,
        ],
      ]);

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  Widget _howItWorks(BuildContext context, bool wide) {
    final p = context.pal;
    final ty = context.ty;
    final items = [
      for (var i = 0; i < _steps.length; i++)
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          CircleAvatar(radius: 16, backgroundColor: p.ultraSoft, child: Text('${i + 1}', style: TextStyle(color: p.ultra, fontWeight: FontWeight.w700))),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_steps[i].$1, style: ty.bodyStrong),
              Text(_steps[i].$2, style: ty.caption.copyWith(fontSize: 14)),
            ]),
          ),
        ]),
    ];
    return SectionCard(
      title: 'How it works',
      subtitle: 'Three steps. No experience needed.',
      trailing: TextButton(onPressed: () => context.go('/help'), child: const Text('More help')),
      child: wide
          ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              for (var i = 0; i < items.length; i++) ...[
                if (i > 0) const SizedBox(width: 16),
                Expanded(child: items[i]),
              ],
            ])
          : Column(children: [for (var i = 0; i < items.length; i++) ...[if (i > 0) const SizedBox(height: 12), items[i]]]),
    );
  }

  Widget _kpis(BuildContext context, bool wide, DashStats s, bool loading) {
    final go = context.go;
    final last = s.last;
    final ch = s.change;
    final best = s.best;
    final wk = s.weekVideos - s.weekPrev;
    final cards = [
      KpiCard(
        filled: true,
        loading: loading,
        label: 'Latest score',
        value: last?.score,
        strip: last?.score.toDouble(),
        note: last == null ? 'Analyse a video to get a score' : (ch == null ? 'Your first score' : delta(ch, 'from last analysis', 'Same as last analysis')),
        onTap: last == null ? null : () => go('/analyses/${last.id}'),
      ),
      KpiCard(
        loading: loading,
        label: s.weekVideos == 1 ? 'Analysis this week' : 'Analyses this week',
        value: s.weekVideos,
        tone: wk.sign,
        note: s.weekVideos == 0 && s.weekPrev == 0 ? 'Nothing yet this week' : delta(wk, 'vs last week', 'Same as last week'),
        onTap: () => go('/history'),
      ),
      KpiCard(
        loading: loading,
        label: 'Best score',
        value: best?.score,
        note: best == null ? 'Nothing to beat yet' : (best.at == null ? 'Your top score so far' : 'Set ${shortDate(best.at)}'),
        onTap: best == null ? null : () => go('/analyses/${best.id}'),
      ),
      KpiCard(
        loading: loading,
        label: 'Average score',
        value: s.average?.round(),
        note: s.completed == 0 ? 'No scores yet' : 'Across ${plural(s.completed, 'analysis', 'analyses')}',
        onTap: () => go('/history'),
      ),
    ];
    final tiles = [for (var i = 0; i < cards.length; i++) _in(60 * i, Lift(child: cards[i]))];
    if (wide) {
      return Row(children: [
        for (var i = 0; i < tiles.length; i++) ...[
          if (i > 0) const SizedBox(width: _g),
          Expanded(child: tiles[i]),
        ],
      ]);
    }
    return LayoutBuilder(builder: (context, c) {
      final w = (c.maxWidth - _g) / 2;
      return Wrap(spacing: _g, runSpacing: _g, children: [for (final t in tiles) SizedBox(width: w, child: t)]);
    });
  }

  Widget _running(BuildContext context, Job j) {
    final ty = context.ty;
    final mood = moodForStage(j.status, j.stage);
    return Panel(
      child: Row(children: [
        PipMark(mood: mood, size: 56),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Analysis in progress', style: ty.heading),
            Text('${j.projectName ?? j.niche}: ${moodCaption(mood)}', maxLines: 2, overflow: TextOverflow.ellipsis, style: ty.caption),
            const SizedBox(height: 8),
            LinearProgressIndicator(value: j.progress / 100, minHeight: 6, borderRadius: BorderRadius.circular(3)),
          ]),
        ),
        const SizedBox(width: 14),
        FilledButton(onPressed: () => context.go('/analyses/${j.id}'), child: const Text('See progress')),
      ]),
    );
  }

  Widget _fixCard(BuildContext context, DashStats s, bool loading) {
    final p = context.pal;
    final ty = context.ty;
    final fix = s.fix;
    return SectionCard(
      title: "Last time's #1 fix",
      child: loading
          ? const Column(children: [Skeleton(height: 18), SizedBox(height: 8), Skeleton(height: 14), SizedBox(height: 8), Skeleton(height: 14)])
          : fix == null
              ? Row(children: [
                  const PipMark(size: 56),
                  const SizedBox(width: 12),
                  Expanded(child: Text('Analyse a video and your top fix will wait for you here.', style: ty.body.copyWith(color: p.mute))),
                ])
              : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(fix.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: ty.bodyStrong),
                  const SizedBox(height: 4),
                  Text(fix.detail, maxLines: 2, overflow: TextOverflow.ellipsis, style: ty.body.copyWith(color: p.mute)),
                  const SizedBox(height: 12),
                  OutlinedButton(onPressed: () => context.go('/analyses/${fix.jobId}'), child: const Text('Open that report')),
                ]),
    );
  }

  Widget _tipCard(BuildContext context, bool wide) => SectionCard(
        title: "Pip's tip",
        expand: wide,
        child: Row(children: [
          const PipMark(size: 56),
          const SizedBox(width: 12),
          Expanded(child: Text(_tips[DateTime.now().weekday % _tips.length], style: context.ty.body.copyWith(color: context.pal.mute))),
        ]),
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(dashboardStatsProvider);
    final s = async.valueOrNull ?? const DashStats();
    final loading = async.isLoading && async.valueOrNull == null;
    final n = s.points.length;
    final running = s.latest.where((j) => j.isActive).firstOrNull;
    return PageFrame(
      child: LayoutBuilder(builder: (context, c) {
        final wide = c.maxWidth > 760;
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          LivePoller(active: Fx.enabled && running != null, onTick: () => ref.invalidate(dashboardStatsProvider)),
          PageHeader(
            title: 'Dashboard',
            subtitle: 'Everything Pip knows about your videos, in one place.',
            actions: [
              FilledButton.icon(onPressed: () => context.go('/new'), icon: const Icon(Icons.add, size: 20), label: const Text('New analysis')),
              OutlinedButton(onPressed: () => context.go('/history'), child: const Text('View history')),
            ],
          ),
          if (running != null) ...[_in(0, _running(context, running)), const SizedBox(height: _g)],
          if (!loading && s.total == 0) ...[_in(0, _howItWorks(context, wide)), const SizedBox(height: _g)],
          _kpis(context, wide, s, loading),
          const SizedBox(height: _g),
          _in(
            240,
            _cols(wide, [
              (
                3,
                SectionCard(
                  title: 'Score per analysis',
                  subtitle: n == 0
                      ? 'Your bars appear after your first report.'
                      : (n == 1 ? 'Your first analysis. Bars grow with every report.' : 'Last ${plural(n, 'analysis', 'analyses')}. Gold marks your best.'),
                  expand: wide,
                  child: loading ? const Skeleton(height: 140) : PillBars(points: s.points, height: wide ? null : 200),
                ),
              ),
              (2, Column(children: [_fixCard(context, s, loading), const SizedBox(height: _g), wide ? Expanded(child: _tipCard(context, true)) : _tipCard(context, false)])),
            ]),
          ),
          const SizedBox(height: _g),
          _in(
            300,
            _cols(wide, [
              (
                3,
                SectionCard(
                  title: 'Your four skills',
                  subtitle: 'From your latest report',
                  expand: wide,
                  child: loading ? const Skeleton(height: 140) : SkillBars(scores: s.skills),
                ),
              ),
              (2, const QuickStudio()),
            ]),
          ),
          if (!loading) ...[
            SectionTitle('Recent reports', trailing: TextButton(onPressed: () => context.go('/history'), child: const Text('See all'))),
            _in(
              360,
              s.latest.isEmpty
                  ? EmptyState(
                      title: 'No reports yet',
                      body: 'Drop a clip and Pip will watch it for you.',
                      actionLabel: 'Drop a clip',
                      onAction: () => context.go('/new'),
                    )
                  : RowList(children: [for (final j in s.latest) JobRow(job: j, showProject: true, onTap: () => context.go('/analyses/${j.id}'))]),
            ),
          ],
        ]);
      }),
    );
  }
}