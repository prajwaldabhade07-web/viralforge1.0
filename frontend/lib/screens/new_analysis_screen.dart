import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../api/api_client.dart';
import '../models.dart';
import '../state/providers.dart';
import '../theme.dart';
import '../util/format.dart';
import '../util/platform.dart';
import '../widgets/common.dart';
import '../widgets/video_drop_area.dart';

enum _Phase { idle, uploading, starting }

class NewAnalysisScreen extends ConsumerStatefulWidget {
  final String projectId;
  final String? existingVideoId;
  const NewAnalysisScreen({super.key, required this.projectId, this.existingVideoId});

  @override
  ConsumerState<NewAnalysisScreen> createState() => _NewAnalysisScreenState();
}

class _NewAnalysisScreenState extends ConsumerState<NewAnalysisScreen> {
  final _form = GlobalKey<FormState>();
  final _niche = TextEditingController();
  final _audience = TextEditingController();
  final _caption = TextEditingController();
  final _script = TextEditingController();

  String _mode = 'video'; // video | script
  String _platform = 'tiktok';
  PickedVideo? _picked;
  VideoItem? _existing;
  String? _uploadedVideoId; // kept so a retry after a failed start never uploads twice
  String? _fileError;
  String? _error;
  _Phase _phase = _Phase.idle;
  double _progress = 0;
  CancelToken? _cancel;

  bool get _busy => _phase != _Phase.idle;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _prefill());
  }

  Future<void> _prefill() async {
    try {
      final p = await ref.read(projectProvider(widget.projectId).future);
      if (!mounted) return;
      setState(() {
        if (p.platform != null) _platform = p.platform!;
        if (_niche.text.isEmpty) _niche.text = p.niche ?? '';
        if (_audience.text.isEmpty) _audience.text = p.targetAudience ?? '';
      });
      if (widget.existingVideoId != null) {
        final vids = await ref.read(projectVideosProvider(widget.projectId).future);
        final match = vids.items.where((v) => v.id == widget.existingVideoId);
        if (mounted && match.isNotEmpty) setState(() => _existing = match.first);
      }
    } catch (_) {
      // Prefill is a convenience only; the form still works.
    }
  }

  @override
  void dispose() {
    _cancel?.cancel();
    _niche.dispose();
    _audience.dispose();
    _caption.dispose();
    _script.dispose();
    super.dispose();
  }

  PublicConfig get _cfg => ref.read(publicConfigProvider).valueOrNull ?? const PublicConfig();

  void _onPicked(PickedVideo v) {
    final msg = validateVideoFile(
      name: v.name,
      sizeBytes: v.size,
      allowedExtensions: _cfg.allowedExtensions,
      maxMb: _cfg.maxUploadMb,
    );
    setState(() {
      _error = null;
      _fileError = msg;
      _picked = msg == null ? v : null;
      if (msg == null) {
        _existing = null;
        _uploadedVideoId = null;
      }
    });
  }

  Future<void> _submit() async {
    if (_busy || !_form.currentState!.validate()) return;
    if (_mode == 'video' && _picked == null && _existing == null && _uploadedVideoId == null) {
      setState(() => _error = 'Choose a video to analyse first.');
      return;
    }
    unawaited(requestNotifyPermission());
    setState(() {
      _error = null;
      _phase = _mode == 'video' && _existing == null && _uploadedVideoId == null ? _Phase.uploading : _Phase.starting;
      _progress = 0;
    });
    final api = ref.read(apiProvider);
    try {
      String? videoId = _existing?.id ?? _uploadedVideoId;
      if (_mode == 'video' && videoId == null) {
        _cancel = CancelToken();
        final v = await api.uploadVideo(
          widget.projectId,
          _picked!.bytes,
          _picked!.name,
          cancelToken: _cancel,
          onProgress: (sent, total) {
            if (total > 0 && mounted) setState(() => _progress = sent / total);
          },
        );
        videoId = v.id;
        _uploadedVideoId = v.id;
      }
      if (mounted) setState(() => _phase = _Phase.starting);
      final job = await api.createAnalysis(widget.projectId, {
        'input_type': _mode,
        if (_mode == 'video') 'video_id': videoId,
        if (_mode == 'script') 'script_text': _script.text.trim(),
        'platform': _platform,
        'niche': _niche.text.trim(),
        'target_audience': _audience.text.trim(),
        if (_caption.text.trim().isNotEmpty) 'caption': _caption.text.trim(),
      });
      ref.invalidate(projectAnalysesProvider(widget.projectId));
      ref.invalidate(projectVideosProvider(widget.projectId));
      ref.invalidate(projectsProvider);
      if (mounted) context.go('/analyses/${job.id}');
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.code == 'cancelled' ? 'Upload cancelled.' : e.message;
        // A rejected file (type, length, contents) must be replaced; other errors keep it for retry.
        if (e.status == 413 || (e.status == 422 && _uploadedVideoId == null && _mode == 'video')) {
          _fileError = e.message;
          _picked = null;
        }
      });
    } finally {
      if (mounted) setState(() => _phase = _Phase.idle);
    }
  }

  Widget _fileCard() {
    final p = context.pal;
    final ty = context.ty;
    final name = _picked?.name ?? _existing?.filename;
    final size = _picked?.size ?? _existing?.sizeBytes;
    if (name == null) {
      final c = _cfg;
      return VideoDropArea(
        enabled: !_busy,
        onPicked: _onPicked,
        onError: (m) => setState(() => _fileError = m),
        limitsText:
            '${c.allowedExtensions.map((e) => e.toUpperCase()).join(', ')}. Up to ${c.maxVideoSeconds.round()} seconds and ${c.maxUploadMb} MB.',
      );
    }
    return Panel(
      child: Row(children: [
        Icon(Icons.movie_outlined, color: p.ultra, size: 28),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: ty.bodyStrong),
            Text(
              [
                if (size != null) formatBytes(size),
                if (_existing?.durationSeconds != null) formatDuration(_existing!.durationSeconds!),
                if (_uploadedVideoId != null) 'uploaded',
              ].join(', '),
              style: ty.caption,
            ),
          ]),
        ),
        TextButton(
          onPressed: _busy || _uploadedVideoId != null
              ? null
              : () => setState(() {
                    _picked = null;
                    _existing = null;
                  }),
          child: const Text('Choose another'),
        ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ty = context.ty;
    final script = _mode == 'script';
    return PageFrame(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Form(
          key: _form,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _busy ? null : () => context.go('/projects/${widget.projectId}'),
                icon: const Icon(Icons.arrow_back, size: 18),
                label: const Text('Back to project'),
              ),
            ),
            const PageHeader(title: 'New analysis', subtitle: 'Add a video and tell Pip where you will post it.'),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'video', label: Text('Video'), icon: Icon(Icons.movie_outlined)),
                ButtonSegment(value: 'script', label: Text('Script only'), icon: Icon(Icons.article_outlined)),
              ],
              selected: {_mode},
              onSelectionChanged: _busy ? null : (s) => setState(() => _mode = s.first),
            ),
            const SizedBox(height: 18),
            if (!script) ...[
              _fileCard(),
              if (_fileError != null) ...[const SizedBox(height: 10), InlineMessage(MsgKind.error, _fileError!)],
            ] else ...[
              const InlineMessage(MsgKind.info,
                  'A script alone cannot show visuals, pacing or audio, so the report is less certain. Uploading the video gives a stronger analysis.'),
              const SizedBox(height: 14),
              TextFormField(
                controller: _script,
                minLines: 8,
                maxLines: 14,
                maxLength: 8000,
                enabled: !_busy,
                decoration: fieldDecoration(context, 'Script', hint: 'Paste the spoken lines and describe the shots.'),
                validator: (v) => (v == null || v.trim().length < 20) ? 'Write at least 20 characters.' : null,
              ),
            ],
            const SizedBox(height: 22),
            Text('Where will you post it?', style: ty.heading),
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final e in platformLabels.entries)
                ChoiceChip(
                  label: Text(e.value),
                  selected: _platform == e.key,
                  onSelected: _busy ? null : (_) => setState(() => _platform = e.key),
                ),
            ]),
            const SizedBox(height: 18),
            TextFormField(
              controller: _niche,
              enabled: !_busy,
              maxLength: 100,
              decoration: fieldDecoration(context, 'Niche', hint: 'Budget cooking'),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter the niche of this video.' : null,
            ),
            const SizedBox(height: 6),
            TextFormField(
              controller: _audience,
              enabled: !_busy,
              maxLength: 200,
              decoration: fieldDecoration(context, 'Target audience', hint: 'College students who cook for one'),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Describe who you want to reach.' : null,
            ),
            const SizedBox(height: 6),
            TextFormField(
              controller: _caption,
              enabled: !_busy,
              maxLength: 2200,
              minLines: 2,
              maxLines: 4,
              decoration: fieldDecoration(context, 'Caption (optional)', helper: 'The caption is considered alongside the video, never instead of it.'),
            ),
            const SizedBox(height: 16),
            if (_error != null) ...[InlineMessage(MsgKind.error, _error!), const SizedBox(height: 14)],
            if (_phase == _Phase.uploading) ...[
              LinearProgressIndicator(value: _progress >= 1 ? null : _progress, minHeight: 8),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                  child: Text(
                    _progress >= 1
                        ? 'Checking your video...'
                        : 'Uploading ${(_progress * 100).round()}%${_picked != null ? ' of ${formatBytes(_picked!.size)}' : ''}',
                    style: ty.caption.copyWith(fontSize: 14),
                  ),
                ),
                TextButton(onPressed: () => _cancel?.cancel(), child: const Text('Cancel upload')),
              ]),
              const SizedBox(height: 8),
            ],
            if (_phase == _Phase.starting) ...[
              const LinearProgressIndicator(minHeight: 8),
              const SizedBox(height: 8),
              Text('Starting the analysis...', style: ty.caption.copyWith(fontSize: 14)),
              const SizedBox(height: 8),
            ],
            FilledButton(
              onPressed: _busy ? null : _submit,
              child: Text(script ? 'Analyse script' : (_uploadedVideoId != null || _existing != null ? 'Start analysis' : 'Upload and analyse')),
            ),
          ]),
        ),
      ),
    );
  }
}