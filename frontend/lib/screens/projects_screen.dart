import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models.dart';
import '../state/providers.dart';
import '../theme.dart';
import '../util/format.dart';
import '../widgets/common.dart';
import '../widgets/fx.dart';
import '../widgets/job_row.dart';
import 'project_dialog.dart';

const _tips = [
  'The first 2 seconds decide everything. Open on the payoff, then rewind to explain.',
  'Most viewers watch with sound off. Add on-screen text for your key line.',
  'Cut every pause longer than half a second. Tight pacing keeps people to the end.',
  'End with a reason to rewatch: a loop, a twist, or a question people will answer in comments.',
  'Make one video about one idea. Clear beats clever.',
  'Post the same idea in 3 hooks and compare the scores. Keep the winner.',
  'Relatable beats polished. People share what feels like them.',
  'Check your captions: a short, curious line outperforms a long summary.',
];

class ProjectsScreen extends ConsumerWidget {
  const ProjectsScreen({super.key});

  Future<void> _create(BuildContext context, WidgetRef ref) async {
    final p = await showProjectDialog(context);
    if (p != null && context.mounted) {
      ref.invalidate(projectsProvider);
      context.go('/projects/${p.id}');
    }
  }

  String _firstName(String? email) {
    if (email == null || email.isEmpty) return 'creator';
    final raw = email.split('@').first.replaceAll(RegExp(r'[^A-Za-z]'), ' ').trim();
    if (raw.isEmpty) return 'creator';
    final n = raw.split(' ').first;
    return '${n[0].toUpperCase()}${n.substring(1)}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projects = ref.watch(projectsProvider);
    final stats = ref.watch(dashboardStatsProvider).valueOrNull;
    final email = ref.watch(authServiceProvider).email;
    final page = projects.valueOrNull;
    final projectCount = page?.total ?? 0;
    final analyses = stats?.total ?? (page?.items.fold<int>(0, (a, p) => a + p.analysisCount) ?? 0);
    final completed = stats?.completed ?? 0;
    final tip = _tips[DateTime.now().day % _tips.length];

    return PageFrame(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Reveal(child: _Hero(name: _firstName(email), onCreate: () => _create(context, ref))),
        const SizedBox(height: 18),
        _StatsRow(projects: projectCount, analyses: analyses, average: stats?.average, best: stats?.best),
        const SizedBox(height: 18),
        if (!(projectCount > 0 && analyses > 0 && completed > 0)) ...[
          Reveal(delayMs: 250, child: _Checklist(hasProject: projectCount > 0, hasAnalysis: analyses > 0, hasReport: completed > 0)),
          const SizedBox(height: 18),
        ],
        LayoutBuilder(builder: (context, c) {
          final trend = Reveal(delayMs: 300, child: _TrendCard(scores: stats?.trend ?? const []));
          final tipCard = Reveal(delayMs: 380, child: _TipCard(text: tip));
          if (c.maxWidth > 760) {
            return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(flex: 3, child: trend),
              const SizedBox(width: 16),
              Expanded(flex: 2, child: tipCard),
            ]);
          }
          return Column(children: [trend, const SizedBox(height: 16), tipCard]);
        }),
        if (stats != null && stats.latest.isNotEmpty) ...[
          const SectionTitle('Latest reports'),
          RowList(children: [
            for (final j in stats.latest) JobRow(job: j, showProject: true, onTap: () => context.go('/analyses/${j.id}')),
          ]),
        ],
        const SectionTitle('Your projects'),
        AsyncBody<Paged<Project>>(
          value: projects,
          onRetry: () => ref.invalidate(projectsProvider),
          data: (pg) {
            if (pg.items.isEmpty) {
              return EmptyState(
                title: 'No projects yet',
                body: 'Create a project, upload a short video, and get your first Viral Readiness Report.',
                actionLabel: 'Create your first project',
                onAction: () => _create(context, ref),
              );
            }
            return LayoutBuilder(builder: (context, c) {
              final cols = c.maxWidth > 900 ? 3 : (c.maxWidth > 560 ? 2 : 1);
              final w = (c.maxWidth - (cols - 1) * 14) / cols;
              return Wrap(spacing: 14, runSpacing: 14, children: [
                for (var i = 0; i < pg.items.length; i++)
                  SizedBox(
                    width: w,
                    child: Reveal(delayMs: 60 * i, child: _ProjectCard(p: pg.items[i], index: i)),
                  ),
              ]);
            });
          },
        ),
      ]),
    );
  }
}

class _Hero extends StatelessWidget {
  final String name;
  final VoidCallback onCreate;
  const _Hero({required this.name, required this.onCreate});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(colors: [Tk.ink, Color(0xFF232C7A)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        ),
        child: Stack(children: [
          const Positioned.fill(child: AmbientBlobs(colors: [Tk.ultra, Tk.pink, Tk.sodium], opacity: 0.4)),
          Padding(
            padding: const EdgeInsets.all(28),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Welcome back, $name', style: display(34, color: Colors.white, height: 1.1)),
              const SizedBox(height: 8),
              const Text('Ready to find out what makes your next clip land?',
                  style: TextStyle(color: Color(0xFFC3CAE0), fontSize: 16, height: 1.4)),
              const SizedBox(height: 20),
              FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: Tk.sodium, foregroundColor: Tk.ink),
                onPressed: onCreate,
                icon: const Icon(Icons.add, size: 20),
                label: const Text('New project'),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  final int projects;
  final int analyses;
  final double? average;
  final int? best;
  const _StatsRow({required this.projects, required this.analyses, required this.average, required this.best});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final cols = c.maxWidth > 760 ? 4 : 2;
      final w = (c.maxWidth - (cols - 1) * 12) / cols;
      final big = display(26, height: 1);
      Widget card(int i, IconData icon, String label, Widget value, Color color) => SizedBox(
            width: w,
            child: Reveal(
              delayMs: 100 + 70 * i,
              child: HoverLift(
                child: Panel(
                  padding: const EdgeInsets.all(16),
                  child: Row(children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(color: color.withOpacity(0.14), borderRadius: BorderRadius.circular(10)),
                      child: Icon(icon, color: color, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        value,
                        const SizedBox(height: 4),
                        Text(label, style: const TextStyle(color: Tk.mute, fontSize: 13)),
                      ]),
                    ),
                  ]),
                ),
              ),
            ),
          );
      return Wrap(spacing: 12, runSpacing: 12, children: [
        card(0, Icons.folder_copy_outlined, 'Total projects', CountUp(value: projects, style: big), Tk.ultra),
        card(1, Icons.insights_outlined, 'Analyses run', CountUp(value: analyses, style: big), Tk.pink),
        card(2, Icons.speed_outlined, 'Average score',
            average == null ? Text('-', style: big) : CountUp(value: average!.round(), style: big), Tk.mint),
        card(3, Icons.emoji_events_outlined, 'Best score',
            best == null ? Text('-', style: big) : CountUp(value: best!, style: big), const Color(0xFFE0A100)),
      ]);
    });
  }
}

class _Checklist extends StatelessWidget {
  final bool hasProject;
  final bool hasAnalysis;
  final bool hasReport;
  const _Checklist({required this.hasProject, required this.hasAnalysis, required this.hasReport});

  Widget _step(bool done, String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(children: [
          Icon(done ? Icons.check_circle : Icons.radio_button_unchecked, color: done ? Tk.good : Tk.line, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text,
                style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: done ? Tk.mute : Tk.ink,
                    decoration: done ? TextDecoration.lineThrough : null)),
          ),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final done = [hasProject, hasAnalysis, hasReport].where((e) => e).length;
    return Panel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text('Get your first report in 3 steps', style: display(18, weight: FontWeight.w600))),
          Text('$done/3', style: const TextStyle(color: Tk.mute, fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(value: done / 3, minHeight: 6, color: Tk.sodium, backgroundColor: Tk.track),
        ),
        const SizedBox(height: 10),
        _step(hasProject, 'Create a project'),
        _step(hasAnalysis, 'Upload a short video and start the analysis'),
        _step(hasReport, 'Read your report and fix the top suggestion'),
      ]),
    );
  }
}

class _TrendCard extends StatelessWidget {
  final List<int> scores;
  const _TrendCard({required this.scores});

  @override
  Widget build(BuildContext context) {
    final ghost = scores.isEmpty;
    final values = ghost ? const [30, 45, 40, 60, 55, 70, 65, 80] : scores;
    return Panel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Score trend', style: display(18, weight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text(
          ghost ? 'Run your first analysis to see how your scores move.' : 'Overall score of your last ${scores.length} analyses.',
          style: const TextStyle(color: Tk.mute, fontSize: 14),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 110,
          width: double.infinity,
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: Fx.enabled ? 0 : 1, end: 1),
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeOutCubic,
            builder: (context, t, _) => CustomPaint(painter: _BarsPainter(values, ghost, t)),
          ),
        ),
      ]),
    );
  }
}

class _BarsPainter extends CustomPainter {
  final List<int> values;
  final bool ghost;
  final double t;
  _BarsPainter(this.values, this.ghost, this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final n = values.length;
    if (n == 0) return;
    const gap = 10.0;
    final bw = (size.width - gap * (n - 1)) / n;
    if (bw < 1) return;
    for (var i = 0; i < n; i++) {
      final h = size.height * (values[i].clamp(0, 100) / 100) * t;
      final color = ghost ? Tk.track : (i == n - 1 ? Tk.sodium : Tk.ultra);
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(i * (bw + gap), size.height - h, bw, h), const Radius.circular(5)),
        Paint()..color = color,
      );
    }
  }

  @override
  bool shouldRepaint(_BarsPainter old) => old.t != t || old.values != values || old.ghost != ghost;
}

class _TipCard extends StatelessWidget {
  final String text;
  const _TipCard({required this.text});

  @override
  Widget build(BuildContext context) {
    return Panel(
      color: Tk.ultraSoft,
      borderColor: Tk.ultraSoft,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.lightbulb_outline, color: Tk.ultra),
          const SizedBox(width: 8),
          Text('Creator tip', style: display(18, weight: FontWeight.w600, color: Tk.ultra)),
        ]),
        const SizedBox(height: 10),
        Text(text, style: const TextStyle(height: 1.5, fontSize: 15)),
      ]),
    );
  }
}

class _ProjectCard extends StatelessWidget {
  final Project p;
  final int index;
  const _ProjectCard({required this.p, required this.index});

  static const _accents = [Tk.ultra, Tk.pink, Tk.mint, Color(0xFFE0A100)];

  @override
  Widget build(BuildContext context) {
    final accent = _accents[index % _accents.length];
    final meta = [if (p.platform != null) platformLabel(p.platform), if ((p.niche ?? '').isNotEmpty) p.niche!].join(', ');
    final count = p.analysisCount == 1 ? '1 analysis' : '${p.analysisCount} analyses';
    final r = BorderRadius.circular(Tk.radius);
    return HoverLift(
      child: Material(
        color: Tk.gate,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: r, side: const BorderSide(color: Tk.line)),
        child: InkWell(
          onTap: () => context.go('/projects/${p.id}'),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(color: accent.withOpacity(0.14), borderRadius: BorderRadius.circular(12)),
                  child: Icon(Icons.movie_filter_outlined, color: accent),
                ),
                const Spacer(),
                const Icon(Icons.arrow_outward, color: Tk.mute, size: 20),
              ]),
              const SizedBox(height: 14),
              Text(p.name, style: display(19, weight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 2),
              Text(meta.isEmpty ? 'No platform set' : meta,
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Tk.mute, fontSize: 14)),
              const SizedBox(height: 14),
              Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: accent.withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
                  child: Text(count, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text('Updated ${formatDateTime(p.updatedAt)}',
                      maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Tk.mute, fontSize: 12.5)),
                ),
              ]),
            ]),
          ),
        ),
      ),
    );
  }
}