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
import '../widgets/common.dart';
import '../widgets/film.dart';
import '../widgets/video_drop_area.dart';
import '../widgets/video_preview.dart';

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
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: p.onHero.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10)),
      child: Row(children: [
        SizedBox(
          width: 100,
          height: 70,
          child: _probe != null
              ? VideoPreview(url: _probe!.url)
              : DecoratedBox(
                  decoration: BoxDecoration(color: p.onHero.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                  child: Icon(Icons.movie_outlined, color: p.heroMute),
                ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(v.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: ty.bodyStrong.copyWith(color: p.onHero)),
            Text(meta, style: ty.caption.copyWith(color: p.heroMute)),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: _phase == _Phase.uploading && _progress < 1 ? _progress : null,
              minHeight: 8,
              color: p.sodium,
              backgroundColor: p.onHero.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(4),
            ),
            const SizedBox(height: 6),
            Row(children: [
              Expanded(child: Text(status, style: ty.caption.copyWith(color: p.heroMute))),
              if (_phase == _Phase.uploading && _progress < 1)
                TextButton(
                  style: TextButton.styleFrom(foregroundColor: p.sodium),
                  onPressed: () => _cancel?.cancel(),
                  child: const Text('Cancel'),
                ),
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
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: p.hero,
        borderRadius: BorderRadius.circular(kRadius),
        border: Border.all(color: p.onHero.withValues(alpha: 0.08)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(kRadius),
        child: Stack(children: [
          GrainOverlay(color: p.onHero.withValues(alpha: 0.05)),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text('Drop a clip. Pip does the rest.', style: ty.heading.copyWith(fontSize: 20, color: p.onHero)),
              const SizedBox(height: 4),
              Text('Quick Studio uploads it, runs the analysis and opens the report.', style: ty.caption.copyWith(color: p.heroMute)),
              const SizedBox(height: 14),
              if (_picked == null)
                VideoDropArea(
                  onDark: true,
                  enabled: !_busy,
                  onPicked: _onPicked,
                  onError: (m) => setState(() => _error = m),
                  limitsText:
                      '${cfg.allowedExtensions.map((e) => e.toUpperCase()).join(', ')}. Up to ${cfg.maxVideoSeconds.round()} seconds and ${cfg.maxUploadMb} MB.',
                )
              else
                _staged(),
              if (_error != null) ...[const SizedBox(height: 12), InlineMessage(MsgKind.error, _error!)],
              const SizedBox(height: 8),
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