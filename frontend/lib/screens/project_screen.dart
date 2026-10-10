import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../api/api_client.dart';
import '../models.dart';
import '../state/providers.dart';
import '../theme.dart';
import '../util/format.dart';
import '../widgets/common.dart';
import '../widgets/job_row.dart';
import 'project_dialog.dart';

class ProjectScreen extends ConsumerWidget {
  final String projectId;
  const ProjectScreen({super.key, required this.projectId});

  void _refresh(WidgetRef ref) {
    ref.invalidate(projectProvider(projectId));
    ref.invalidate(projectAnalysesProvider(projectId));
    ref.invalidate(projectVideosProvider(projectId));
    ref.invalidate(projectsProvider);
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, Project p) async {
    final ok = await confirmDialog(context,
        title: 'Delete "${p.name}"?',
        body: 'This permanently deletes the project, its uploaded videos and all of its reports.',
        confirmLabel: 'Delete project');
    if (!ok || !context.mounted) return;
    try {
      await ref.read(apiProvider).deleteProject(p.id);
      ref.invalidate(projectsProvider);
      if (context.mounted) {
        toast(context, 'Project deleted.');
        context.go('/projects');
      }
    } on ApiException catch (e) {
      if (context.mounted) toast(context, e.message);
    }
  }

  Future<void> _deleteVideo(BuildContext context, WidgetRef ref, VideoItem v) async {
    final ok = await confirmDialog(context,
        title: 'Delete this video?',
        body: '"${v.filename}" will be removed from storage. Existing reports are kept.',
        confirmLabel: 'Delete video');
    if (!ok || !context.mounted) return;
    try {
      await ref.read(apiProvider).deleteVideo(v.id);
      _refresh(ref);
      if (context.mounted) toast(context, 'Video deleted.');
    } on ApiException catch (e) {
      if (context.mounted) toast(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final project = ref.watch(projectProvider(projectId));
    return PageFrame(
      child: project.when(
        loading: () => const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator())),
        error: (e, _) => ErrorState(error: e, onRetry: () => _refresh(ref)),
        data: (p) {
          final meta = [
            if (p.platform != null) platformLabel(p.platform),
            if ((p.niche ?? '').isNotEmpty) p.niche!,
            if ((p.targetAudience ?? '').isNotEmpty) 'for ${p.targetAudience}',
          ].join(', ');
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => context.go('/projects'),
                icon: const Icon(Icons.arrow_back, size: 18),
                label: const Text('All projects'),
              ),
            ),
            PageHeader(
              title: p.name,
              subtitle: meta.isEmpty ? (p.description ?? '') : meta,
              actions: [
                FilledButton.icon(
                  onPressed: () => context.go('/projects/${p.id}/new'),
                  icon: const Icon(Icons.upload_outlined, size: 20),
                  label: const Text('New analysis'),
                ),
                PopupMenuButton<String>(
                  tooltip: 'Project options',
                  onSelected: (v) async {
                    if (v == 'edit') {
                      final saved = await showProjectDialog(context, existing: p);
                      if (saved != null) _refresh(ref);
                    } else if (v == 'delete') {
                      await _delete(context, ref, p);
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'edit', child: Text('Edit details')),
                    PopupMenuItem(value: 'delete', child: Text('Delete project')),
                  ],
                  child: Container(
                    height: 46,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(border: Border.all(color: Tk.line), borderRadius: BorderRadius.circular(10), color: Tk.gate),
                    child: const Row(mainAxisSize: MainAxisSize.min, children: [Text('Options', style: TextStyle(fontWeight: FontWeight.w600)), Icon(Icons.arrow_drop_down)]),
                  ),
                ),
              ],
            ),
            const SectionTitle('Analyses'),
            AsyncBody<Paged<Job>>(
              value: ref.watch(projectAnalysesProvider(projectId)),
              onRetry: () => _refresh(ref),
              data: (page) => page.items.isEmpty
                  ? EmptyState(
                      title: 'No analyses yet',
                      body: 'Upload a video to get scores, fixes and simulated audience reactions.',
                      actionLabel: 'Upload a video',
                      onAction: () => context.go('/projects/${p.id}/new'),
                    )
                  : RowList(children: [
                      for (final j in page.items) JobRow(job: j, onTap: () => context.go('/analyses/${j.id}')),
                    ]),
            ),
            const SectionTitle('Uploaded videos'),
            AsyncBody<Paged<VideoItem>>(
              value: ref.watch(projectVideosProvider(projectId)),
              onRetry: () => _refresh(ref),
              data: (page) => page.items.isEmpty
                  ? const Text('No videos uploaded.', style: TextStyle(color: Tk.mute))
                  : RowList(children: [
                      for (final v in page.items)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          child: Row(children: [
                            const Icon(Icons.movie_outlined, color: Tk.mute),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(v.filename, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
                                Text(
                                  '${formatBytes(v.sizeBytes)}${v.durationSeconds != null ? ', ${formatDuration(v.durationSeconds!)}' : ''}',
                                  style: const TextStyle(color: Tk.mute, fontSize: 13),
                                ),
                              ]),
                            ),
                            TextButton(onPressed: () => context.go('/projects/${p.id}/new?video=${v.id}'), child: const Text('Analyse')),
                            IconButton(
                              tooltip: 'Delete video',
                              icon: const Icon(Icons.delete_outline, color: Tk.mute),
                              onPressed: () => _deleteVideo(context, ref, v),
                            ),
                          ]),
                        ),
                    ]),
            ),
          ]);
        },
      ),
    );
  }
}
