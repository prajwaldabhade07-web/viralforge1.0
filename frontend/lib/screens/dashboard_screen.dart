import 'dart:async';

import 'package:dio/dio.dart' show CancelToken;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../api/api_client.dart';
import '../models.dart';
import '../state/providers.dart';
import '../theme.dart';
import '../util/format.dart';
import '../util/platform.dart';
import '../util/studio.dart';
import '../util/text.dart';
import '../widgets/common.dart';
import '../widgets/film.dart';
import '../widgets/frame_strip.dart';
import '../widgets/fx.dart';
import '../widgets/job_row.dart';
import '../widgets/pip.dart';
import '../widgets/video_drop_area.dart';
import '../widgets/video_preview.dart';

const _tips = [
  'Open on the payoff, then explain. The first two seconds decide everything.',
  'Most people watch with the sound off. Put your key line on screen.',
  'Cut every pause longer than half a second.',
  'End on a reason to rewatch: a loop, a twist, or a question.',
  'One video, one idea. Clear beats clever.',
  'Try three hooks on the same idea and keep the best score.',
  'Relatable beats polished. People share what feels like them.',
];

String _firstName(String? email) {
  if (email == null || email.isEmpty) return 'creator';
  final raw = email.split('@').first.replaceAll(RegExp(r'[^A-Za-z]'), ' ').trim();
  if (raw.isEmpty) return 'creator';
  final n = raw.split(' ').first;
  return '${n[0].toUpperCase()}${n.substring(1)}';
}

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(dashboardStatsProvider);
    final stats = async.valueOrNull;
    final loading = async.isLoading && stats == null;
    final email = ref.watch(authServiceProvider).email;
    final active = stats?.latest.any((j) => j.isActive) ?? false;
    return PageFrame(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        LivePoller(active: Fx.enabled && active, onTick: () => ref.invalidate(dashboardStatsProvider)),
        PageHeader(title: 'Hey ${_firstName(email)}', subtitle: 'Drop a clip and Pip will tell you how it lands.'),
        const QuickStudio(),
        const SizedBox(height: 20),
        _Widgets(stats: stats, loading: loading),
        if (stats != null && stats.latest.isNotEmpty) ...[
          const SectionTitle('Latest reports'),
          RowList(children: [
            for (final j in stats.latest) JobRow(job: j, showProject: true, onTap: () => context.go('/analyses/${j.id}')),
          ]),
        ],
      ]),
    );
  }
}

// ───────────────────────── Quick Studio ─────────────────────────

enum _Phase { idle, probing, uploading, starting }

class QuickStudio extends ConsumerStatefulWidget {
  const QuickStudio({super.key});

  @override
  ConsumerState<QuickStudio> createState() => _QuickStudioState();
}

class _QuickStudioState extends ConsumerState<QuickStudio> {
  StudioDefaults _d = StudioDefaults.load();
  _Phase _phase = _Phase.idle;
  PickedVideo? _picked;
  VideoProbe? _probe;
  String? _error;
  double _progress = 0;
  CancelToken? _cancel;

  bool get _busy => _phase != _Phase.idle;

  PublicConfig get _cfg => ref.read(publicConfigProvider).valueOrNull ?? const PublicConfig();

  @override
  void dispose() {
    _cancel?.cancel();
    final u = _probe?.url;
    if (u != null) releaseObjectUrl(u);
    super.dispose();
  }

  String _mime(String name) {
    final e = fileExtension(name);
    if (e == 'webm') return 'video/webm';
    if (e == 'mov') return 'video/quicktime';
    return 'video/mp4';
  }

  void _forget() {
    final u = _probe?.url;
    if (u != null) releaseObjectUrl(u);
    _probe = null;
    _picked = null;
  }

  Future<StudioDefaults?> _editDefaults() async {
    final r = await showDialog<StudioDefaults>(context: context, builder: (_) => _DefaultsDialog(current: _d));
    if (r != null) {
      r.save();
      if (mounted) setState(() => _d = r);
    }
    return r;
  }

  Future<void> _onPicked(PickedVideo v) async {
    if (_busy) return;
    unawaited(requestNotifyPermission());
    final cfg = _cfg;
    final msg = validateVideoFile(
        name: v.name, sizeBytes: v.size, allowedExtensions: cfg.allowedExtensions, maxMb: cfg.maxUploadMb);
    if (msg != null) {
      setState(() => _error = msg);
      return;
    }
    if (!_d.complete) {
      final saved = await _editDefaults();
      if (!mounted) return;
      if (saved == null || !saved.complete) {
        setState(() => _error = 'Set your platform, niche and audience, then drop the clip again.');
        return;
      }
    }
    setState(() {
      _error = null;
      _picked = v;
      _phase = _Phase.probing;
    });
    final probe = await probeVideo(v.bytes, _mime(v.name));
    if (!mounted) {
      if (probe != null) releaseObjectUrl(probe.url);
      return;
    }
    final secs = probe?.seconds;
    if (secs != null) {
      String? bad;
      if (secs < cfg.minVideoSeconds) {
        bad = 'This clip is ${formatDuration(secs)}. It needs to be at least ${cfg.minVideoSeconds.round()} s.';
      } else if (secs > cfg.maxVideoSeconds) {
        bad = 'This clip is ${formatDuration(secs)}. The limit is ${cfg.maxVideoSeconds.round()} seconds, so trim it and drop it again.';
      }
      if (bad != null) {
        if (probe != null) releaseObjectUrl(probe.url);
        setState(() {
          _error = bad;
          _picked = null;
          _phase = _Phase.idle;
        });
        return;
      }
    }
    setState(() => _probe = probe);
    await _run(v);
  }

  Future<String> _quickProject(ApiClient api) async {
    final saved = readPref('vf_quick_project');
    if (saved != null && saved.isNotEmpty) {
      try {
        final p = await api.getProject(saved);
        return p.id;
      } catch (_) {
        // fall through: look it up or create it
      }
    }
    final page = await api.listProjects(limit: 100);
    for (final p in page.items) {
      if (p.name == kQuickProject) {
        writePref('vf_quick_project', p.id);
        return p.id;
      }
    }
    final created = await api.createProject({'name': kQuickProject, 'description': 'Videos analysed from the dashboard.'});
    writePref('vf_quick_project', created.id);
    return created.id;
  }

  Future<void> _run(PickedVideo v) async {
    final api = ref.read(apiProvider);
    setState(() {
      _phase = _Phase.uploading;
      _progress = 0;
      _cancel = CancelToken();
    });
    try {
      final projectId = await _quickProject(api);
      final video = await api.uploadVideo(
        projectId,
        v.bytes,
        v.name,
        cancelToken: _cancel,
        onProgress: (sent, total) {
          if (total > 0 && mounted) setState(() => _progress = sent / total);
        },
      );
      if (mounted) setState(() => _phase = _Phase.starting);
      final job = await api.createAnalysis(projectId, {
        'input_type': 'video',
        'video_id': video.id,
        'platform': _d.platform,
        'niche': _d.niche,
        'target_audience': _d.audience,
      });
      ref.invalidate(projectsProvider);
      ref.invalidate(dashboardStatsProvider);
      if (mounted) context.go('/analyses/${job.id}');
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.code == 'cancelled' ? 'Upload cancelled.' : e.message;
          _forget();
        });
      }
    } finally {
      if (mounted) setState(() => _phase = _Phase.idle);
    }
  }

  Widget _staged() {
    final p = context.pal;
    final ty = context.ty;
    final v = _picked!;
    final secs = _probe?.seconds;
    final meta = [formatBytes(v.size), if (secs != null) formatDuration(secs)].join(', ');
    final String status;
    if (_phase == _Phase.probing) {
      status = 'Checking your clip...';
    } else if (_phase == _Phase.starting) {
      status = 'Starting the analysis...';
    } else if (_progress >= 1) {
      status = 'Checking your video...';
    } else {
      status = 'Uploading ${(_progress * 100).round()}%';
    }
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: p.surface, borderRadius: BorderRadius.circular(kRadius)),
      child: Row(children: [
        SizedBox(
          width: 160,
          height: 100,
          child: _probe != null
              ? VideoPreview(url: _probe!.url)
              : DecoratedBox(
                  decoration: BoxDecoration(color: p.surfaceAlt, borderRadius: BorderRadius.circular(10)),
                  child: Icon(Icons.movie_outlined, color: p.mute),
                ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(v.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: ty.bodyStrong),
            Text(meta, style: ty.caption),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: _phase == _Phase.uploading && _progress < 1 ? _progress : null,
              minHeight: 8,
              borderRadius: BorderRadius.circular(4),
            ),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: Text(status, style: ty.caption)),
              if (_phase == _Phase.uploading && _progress < 1)
                TextButton(onPressed: () => _cancel?.cancel(), child: const Text('Cancel')),
            ]),
          ]),
        ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final ty = context.ty;
    final cfg = ref.watch(publicConfigProvider).valueOrNull ?? const PublicConfig();
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: double.infinity,
        color: p.hero,
        child: Stack(children: [
          GrainOverlay(color: p.onHero.withValues(alpha: 0.05)),
          SprocketOverlay(color: p.onHero.withValues(alpha: 0.14)),
          Padding(
            padding: const EdgeInsets.fromLTRB(28, 34, 28, 34),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Drop a clip. Pip does the rest.', style: ty.display.copyWith(fontSize: 34, color: p.onHero)),
              const SizedBox(height: 6),
              Text('Quick Studio uploads it, runs the analysis and takes you to the report.',
                  style: ty.body.copyWith(color: p.heroMute)),
              const SizedBox(height: 18),
              if (_picked == null)
                VideoDropArea(
                  enabled: !_busy,
                  onPicked: _onPicked,
                  onError: (m) => setState(() => _error = m),
                  limitsText:
                      '${cfg.allowedExtensions.map((e) => e.toUpperCase()).join(', ')}. Up to ${cfg.maxVideoSeconds.round()} seconds and ${cfg.maxUploadMb} MB.',
                )
              else
                _staged(),
              if (_error != null) ...[const SizedBox(height: 12), InlineMessage(MsgKind.error, _error!)],
              const SizedBox(height: 10),
              Row(children: [
                Expanded(
                  child: Text(
                    _d.complete
                        ? 'Posting to ${platformLabel(_d.platform)}, ${_d.niche}, for ${_d.audience}.'
                        : 'Tell Pip where you post and who watches, once.',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: ty.caption.copyWith(color: p.heroMute),
                  ),
                ),
                TextButton(
                  onPressed: _busy ? null : _editDefaults,
                  style: TextButton.styleFrom(foregroundColor: p.sodium),
                  child: Text(_d.complete ? 'Change' : 'Set up'),
                ),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _DefaultsDialog extends StatefulWidget {
  final StudioDefaults current;
  const _DefaultsDialog({required this.current});

  @override
  State<_DefaultsDialog> createState() => _DefaultsDialogState();
}

class _DefaultsDialogState extends State<_DefaultsDialog> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _niche = TextEditingController(text: widget.current.niche);
  late final TextEditingController _aud = TextEditingController(text: widget.current.audience);
  late String _platform = widget.current.platform;

  @override
  void dispose() {
    _niche.dispose();
    _aud.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Your usual setup'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _form,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final e in platformLabels.entries)
                  ChoiceChip(label: Text(e.value), selected: _platform == e.key, onSelected: (_) => setState(() => _platform = e.key)),
              ]),
              const SizedBox(height: 16),
              TextFormField(
                controller: _niche,
                maxLength: 100,
                decoration: fieldDecoration(context, 'Niche', hint: 'Budget cooking'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter your niche.' : null,
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _aud,
                maxLength: 200,
                decoration: fieldDecoration(context, 'Target audience', hint: 'College students who cook for one'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Describe who you want to reach.' : null,
              ),
            ]),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            if (!_form.currentState!.validate()) return;
            Navigator.pop(context, StudioDefaults(platform: _platform, niche: _niche.text.trim(), audience: _aud.text.trim()));
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

// ───────────────────────── Dashboard widgets ─────────────────────────

class _Widgets extends StatelessWidget {
  final DashStats? stats;
  final bool loading;
  const _Widgets({required this.stats, required this.loading});

  @override
  Widget build(BuildContext context) {
    final s = stats ?? const DashStats();
    return LayoutBuilder(builder: (context, c) {
      final trend = _TrendCard(stats: s, loading: loading);
      final streak = _StreakCard(stats: s, loading: loading);
      final fix = _FixCard(stats: s, loading: loading);
      const tip = _TipCard();
      if (c.maxWidth > 760) {
        return Column(children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(flex: 3, child: trend),
            const SizedBox(width: 16),
            Expanded(flex: 2, child: streak),
          ]),
          const SizedBox(height: 16),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(flex: 3, child: fix),
            const SizedBox(width: 16),
            const Expanded(flex: 2, child: tip),
          ]),
        ]);
      }
      return Column(children: [trend, const SizedBox(height: 12), streak, const SizedBox(height: 12), fix, const SizedBox(height: 12), tip]);
    });
  }
}

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) => SizedBox(height: 212, child: Panel(child: child));
}

class _TrendCard extends StatelessWidget {
  final DashStats stats;
  final bool loading;
  const _TrendCard({required this.stats, required this.loading});

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final ty = context.ty;
    if (loading) {
      return const _Card(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Skeleton(width: 90),
          SizedBox(height: 16),
          Skeleton(width: 120, height: 48),
          SizedBox(height: 16),
          Skeleton(height: 16),
        ]),
      );
    }
    final n = stats.trend.length;
    final latest = stats.latestScore;
    final String hint;
    if (n == 0) {
      hint = 'Your trend shows up after your first report.';
    } else {
      hint = '${plural(n, 'analysis', 'analyses')} so far. One more unlocks your trend.';
    }
    return _Card(
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
          width: 150,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Latest score', style: ty.caption),
            const SizedBox(height: 6),
            Text(latest == null ? '-' : '$latest', style: ty.score.copyWith(fontSize: 56)),
            const SizedBox(height: 14),
            FrameStrip(value: (latest ?? 0).toDouble(), cells: 10, height: 12, animate: false, perforated: true),
          ]),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: n >= 2
              ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Last ${plural(n, 'analysis', 'analyses')}', style: ty.caption),
                  const SizedBox(height: 8),
                  Expanded(
                    child: CustomPaint(
                      painter: _SparkPainter(stats.trend, p.ultra, p.sodium, p.line),
                      size: Size.infinite,
                    ),
                  ),
                ])
              : Center(child: Text(hint, style: ty.body.copyWith(color: p.mute))),
        ),
      ]),
    );
  }
}

class _SparkPainter extends CustomPainter {
  final List<int> v;
  final Color line;
  final Color dot;
  final Color grid;
  _SparkPainter(this.v, this.line, this.dot, this.grid);

  @override
  void paint(Canvas canvas, Size size) {
    final n = v.length;
    if (n < 2) return;
    const pad = 10.0;
    final w = size.width - pad * 2;
    final h = size.height - pad * 2;
    if (w <= 0 || h <= 0) return;
    Offset pt(int i) => Offset(pad + w * i / (n - 1), pad + h * (1 - v[i].clamp(0, 100) / 100));
    final gp = Paint()
      ..color = grid
      ..strokeWidth = 1;
    for (final f in const [0.0, 0.5, 1.0]) {
      canvas.drawLine(Offset(pad, pad + h * f), Offset(pad + w, pad + h * f), gp);
    }
    final path = Path()..moveTo(pt(0).dx, pt(0).dy);
    for (var i = 1; i < n; i++) {
      path.lineTo(pt(i).dx, pt(i).dy);
    }
    final area = Path.from(path)
      ..lineTo(pt(n - 1).dx, pad + h)
      ..lineTo(pt(0).dx, pad + h)
      ..close();
    canvas.drawPath(area, Paint()..color = line.withValues(alpha: 0.12));
    canvas.drawPath(
        path,
        Paint()
          ..color = line
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round);
    for (var i = 0; i < n - 1; i++) {
      canvas.drawCircle(pt(i), 3.5, Paint()..color = line);
    }
    canvas.drawCircle(pt(n - 1), 7, Paint()..color = line);
    canvas.drawCircle(pt(n - 1), 4.5, Paint()..color = dot);
  }

  @override
  bool shouldRepaint(_SparkPainter old) => old.v != v || old.line != line || old.dot != dot || old.grid != grid;
}

class _StreakCard extends StatelessWidget {
  final DashStats stats;
  final bool loading;
  const _StreakCard({required this.stats, required this.loading});

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final ty = context.ty;
    if (loading) {
      return const _Card(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Skeleton(width: 70),
          SizedBox(height: 14),
          Skeleton(width: 160, height: 26),
          SizedBox(height: 30),
          Skeleton(height: 28),
        ]),
      );
    }
    final n = stats.weekVideos;
    const letters = 'MTWTFSS';
    final now = DateTime.now();
    return _Card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Your week', style: ty.caption),
        const SizedBox(height: 6),
        Text('$n ${n == 1 ? 'video' : 'videos'} this week', style: ty.title.copyWith(fontSize: 24)),
        const SizedBox(height: 4),
        Text(n == 0 ? 'Drop a clip to light the first frame.' : 'Keep the reel rolling.', style: ty.caption),
        const Spacer(),
        Row(children: [
          for (var i = 0; i < 7; i++)
            Expanded(
              child: Column(children: [
                Container(
                  height: 28,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    color: stats.weekDays[i] ? (i == 6 ? p.sodium : p.ultra) : p.track,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 4),
                Text(letters[now.subtract(Duration(days: 6 - i)).weekday - 1], style: ty.caption.copyWith(fontSize: 11)),
              ]),
            ),
        ]),
      ]),
    );
  }
}

class _FixCard extends StatelessWidget {
  final DashStats stats;
  final bool loading;
  const _FixCard({required this.stats, required this.loading});

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final ty = context.ty;
    if (loading) {
      return const _Card(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Skeleton(width: 120),
          SizedBox(height: 14),
          Skeleton(height: 20),
          SizedBox(height: 10),
          Skeleton(height: 14),
        ]),
      );
    }
    final fix = stats.fix;
    return _Card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text("Last time's #1 fix", style: ty.caption),
        const SizedBox(height: 8),
        if (fix == null)
          Expanded(
            child: Row(children: [
              const PipMark(size: 72),
              const SizedBox(width: 12),
              Expanded(child: Text('Analyse a video and your top fix will wait for you here.', style: ty.body.copyWith(color: p.mute))),
            ]),
          )
        else ...[
          Text(fix.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: ty.heading),
          const SizedBox(height: 4),
          Expanded(child: Text(fix.detail, maxLines: 2, overflow: TextOverflow.ellipsis, style: ty.body.copyWith(color: p.mute))),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(onPressed: () => context.go('/analyses/${fix.jobId}'), child: const Text('Open that report')),
          ),
        ],
      ]),
    );
  }
}

class _TipCard extends StatelessWidget {
  const _TipCard();

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final ty = context.ty;
    return _Card(
      child: Row(children: [
        const PipMark(size: 64),
        const SizedBox(width: 14),
        Expanded(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text("Pip's tip", style: ty.caption.copyWith(color: p.ultra, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(_tips[DateTime.now().weekday % _tips.length], style: ty.body, maxLines: 5, overflow: TextOverflow.ellipsis),
          ]),
        ),
      ]),
    );
  }
}