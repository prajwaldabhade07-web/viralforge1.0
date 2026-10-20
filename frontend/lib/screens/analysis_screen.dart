import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../api/api_client.dart';
import '../models.dart';
import '../state/providers.dart';
import '../theme.dart';
import '../util/platform.dart';
import '../widgets/common.dart';
import '../widgets/pip.dart';
import '../widgets/report_view.dart';

class AnalysisScreen extends ConsumerStatefulWidget {
  final String jobId;
  const AnalysisScreen({super.key, required this.jobId});

  @override
  ConsumerState<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends ConsumerState<AnalysisScreen> {
  JobDetail? _detail;
  ApiException? _error;
  bool _offline = false;
  bool _busy = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    _timer?.cancel();
    try {
      final d = await ref.read(apiProvider).getAnalysis(widget.jobId);
      if (!mounted) return;
      final wasActive = _detail?.job.isActive ?? false;
      setState(() {
        _detail = d;
        _error = null;
        _offline = false;
      });
      if (wasActive && !d.job.isActive) {
        notifyDone(d.job.status == 'completed' ? 'Your report is ready' : "Your analysis didn't finish", d.job.projectName ?? 'ViralForge');
      }
      if (d.job.isActive) _timer = Timer(const Duration(milliseconds: 2500), _load);
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.isNetwork && _detail != null) {
        setState(() => _offline = true);
        _timer = Timer(const Duration(seconds: 5), _load);
      } else {
        setState(() => _error = e);
      }
    }
  }

  Future<void> _retry() async {
    setState(() => _busy = true);
    try {
      await ref.read(apiProvider).retryAnalysis(widget.jobId);
      await _load();
    } on ApiException catch (e) {
      if (mounted) toast(context, e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete(Job job) async {
    final ok = await confirmDialog(context,
        title: 'Delete this analysis?',
        body: 'The report will be permanently deleted. The uploaded video is kept.',
        confirmLabel: 'Delete analysis');
    if (!ok || !mounted) return;
    try {
      await ref.read(apiProvider).deleteAnalysis(job.id);
      ref.invalidate(projectAnalysesProvider(job.projectId));
      ref.invalidate(projectsProvider);
      ref.invalidate(dashboardStatsProvider);
      if (mounted) {
        toast(context, 'Analysis deleted.');
        context.go('/projects/${job.projectId}');
      }
    } on ApiException catch (e) {
      if (mounted) toast(context, e.message);
    }
  }

  Widget _header(Job job) {
    final p = context.pal;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        TextButton.icon(
          onPressed: () => context.go('/projects/${job.projectId}'),
          icon: const Icon(Icons.arrow_back, size: 18),
          label: Text(job.projectName ?? 'Back to project'),
        ),
        const Spacer(),
        if (!job.isActive)
          IconButton(tooltip: 'Delete analysis', icon: Icon(Icons.delete_outline, color: p.mute), onPressed: () => _delete(job)),
      ]),
      if (_offline) ...[
        const InlineMessage(MsgKind.warn, 'Connection lost. Retrying automatically...'),
        const SizedBox(height: 12),
      ],
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final d = _detail;
    if (d == null) {
      return PageFrame(
        child: _error != null ? ErrorState(error: _error!, onRetry: _load) : const SkeletonList(rows: 4),
      );
    }
    final job = d.job;
    if (!job.isActive && job.status != 'failed' && d.report != null) {
      return ReportView(key: ValueKey(job.id), report: d.report!, job: job, header: _header(job));
    }
    return PageFrame(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _header(job),
        if (job.isActive)
          ProgressPanel(job: job)
        else if (job.status == 'failed')
          _FailurePanel(job: job, busy: _busy, onRetry: _retry)
        else
          const InlineMessage(MsgKind.warn, 'This analysis finished, but its report is not available.'),
      ]),
    );
  }
}

const _stages = <(String, String)>[
  ('queued', 'Waiting for its turn'),
  ('preparing_video', 'Preparing your video'),
  ('uploading', 'Sending it to the AI'),
  ('moderating', 'Running the safety check'),
  ('analyzing', 'Analysing the content'),
  ('simulating_audience', 'Simulating audience reactions'),
  ('finalizing', 'Writing your report'),
];

class ProgressPanel extends StatelessWidget {
  final Job job;
  const ProgressPanel({super.key, required this.job});

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final ty = context.ty;
    final script = job.inputType == 'script';
    final stages = _stages.where((s) => !(script && (s.$1 == 'preparing_video' || s.$1 == 'uploading'))).toList();
    final key = job.stage == 'validating' ? (script ? 'moderating' : 'preparing_video') : job.stage;
    var current = stages.indexWhere((s) => s.$1 == key);
    if (current < 0) current = 0;
    final retrying = job.stage == 'retrying';
    final mood = moodForStage(job.status, job.stage);
    return Panel(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        PipBooth(mood: mood),
        const SizedBox(height: 16),
        Text(job.status == 'queued' ? 'Your analysis is queued' : (script ? "Pip's reading your script" : "Pip's watching your video"),
            style: ty.title),
        const SizedBox(height: 4),
        Text(moodCaption(mood), style: ty.bodyStrong.copyWith(color: p.ultra)),
        const SizedBox(height: 6),
        Text('You can leave this page. The analysis keeps running and will be in your history.', style: ty.body.copyWith(color: p.mute)),
        const SizedBox(height: 18),
        LinearProgressIndicator(value: job.progress / 100, minHeight: 8, borderRadius: BorderRadius.circular(4)),
        const SizedBox(height: 6),
        Text('${job.progress}%', style: ty.caption),
        if (retrying) ...[
          const SizedBox(height: 14),
          const InlineMessage(MsgKind.warn, 'The AI service was busy. Retrying automatically in a moment.'),
        ],
        const SizedBox(height: 18),
        for (var i = 0; i < stages.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(children: [
              if (i < current)
                Icon(Icons.check_circle, color: p.good, size: 20)
              else if (i == current && !retrying)
                SizedBox(
                  width: 20,
                  height: 20,
                  child: Padding(padding: const EdgeInsets.all(2), child: CircularProgressIndicator(strokeWidth: 2.5, color: p.ultra)),
                )
              else
                Icon(Icons.circle_outlined, color: p.line, size: 20),
              const SizedBox(width: 12),
              Text(stages[i].$2,
                  style: TextStyle(fontWeight: i == current ? FontWeight.w700 : FontWeight.w500, color: i > current ? p.mute : p.text)),
            ]),
          ),
      ]),
    );
  }
}

class _FailurePanel extends StatelessWidget {
  final Job job;
  final bool busy;
  final VoidCallback onRetry;
  const _FailurePanel({required this.job, required this.busy, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final ty = context.ty;
    final blocked = job.isBlocked;
    return Panel(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (!blocked) ...[const PipBooth(mood: PipMood.failed, height: 190), const SizedBox(height: 14)],
        Row(children: [StatusPill('failed', blocked: blocked)]),
        const SizedBox(height: 14),
        Text(blocked ? 'This submission was blocked' : "The analysis didn't finish", style: ty.title),
        const SizedBox(height: 10),
        Text(job.errorMessage ?? 'Something went wrong while analysing.', style: ty.body),
        if (!blocked) ...[
          const SizedBox(height: 6),
          Text('Attempt ${job.attempts} of ${job.maxAttempts}', style: ty.caption.copyWith(color: p.mute)),
        ],
        const SizedBox(height: 20),
        Wrap(spacing: 10, runSpacing: 10, children: [
          if (job.retryable) FilledButton(onPressed: busy ? null : onRetry, child: const Text('Retry analysis')),
          OutlinedButton(
            onPressed: () => context.go(job.retryable || blocked ? '/projects/${job.projectId}' : '/projects/${job.projectId}/new'),
            child: Text(job.retryable || blocked ? 'Back to project' : 'Start a new analysis'),
          ),
        ]),
      ]),
    );
  }
}