import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../api/api_client.dart';
import '../models.dart';
import '../state/providers.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/job_row.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  final List<Job> _jobs = [];
  int _total = 0;
  bool _loading = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load(reset: true);
  }

  Future<void> _load({bool reset = false}) async {
    setState(() {
      _loading = true;
      _error = null;
      if (reset) _jobs.clear();
    });
    try {
      final page = await ref.read(apiProvider).history(limit: 20, offset: _jobs.length);
      if (!mounted) return;
      setState(() {
        _jobs.addAll(page.items);
        _total = page.total;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Keeps in-progress rows live without flashing the list.
  Future<void> _refreshQuietly() async {
    if (_loading) return;
    try {
      final n = _jobs.length < 20 ? 20 : (_jobs.length > 100 ? 100 : _jobs.length);
      final page = await ref.read(apiProvider).history(limit: n, offset: 0);
      if (!mounted) return;
      setState(() {
        _jobs
          ..clear()
          ..addAll(page.items);
        _total = page.total;
      });
    } catch (_) {
      // The next tick tries again.
    }
  }

  @override
  Widget build(BuildContext context) {
    return PageFrame(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        LivePoller(active: Fx.enabled && _jobs.any((j) => j.isActive), onTick: _refreshQuietly),
        const PageHeader(title: 'History', subtitle: 'Every analysis across your projects, newest first.'),
        if (_error != null) ErrorState(error: _error!, onRetry: () => _load(reset: _jobs.isEmpty)),
        if (_jobs.isEmpty && !_loading && _error == null)
          EmptyState(
            title: 'No analyses yet',
            body: 'Reports show up here after Pip watches your first video.',
            actionLabel: 'Go to projects',
            onAction: () => context.go('/projects'),
          ),
        if (_jobs.isNotEmpty)
          RowList(children: [
            for (final j in _jobs) JobRow(job: j, showProject: true, onTap: () => context.go('/analyses/${j.id}')),
          ]),
        if (_loading && _jobs.isEmpty) const SkeletonList(rows: 4),
        if (_loading && _jobs.isNotEmpty) const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator())),
        if (!_loading && _jobs.length < _total)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Center(child: OutlinedButton(onPressed: () => _load(), child: const Text('Load more'))),
          ),
      ]),
    );
  }
}