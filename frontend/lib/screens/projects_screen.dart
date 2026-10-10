import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models.dart';
import '../state/providers.dart';
import '../theme.dart';
import '../util/format.dart';
import '../widgets/common.dart';
import '../widgets/job_row.dart';
import 'project_dialog.dart';

class ProjectsScreen extends ConsumerWidget {
  const ProjectsScreen({super.key});

  Future<void> _create(BuildContext context, WidgetRef ref) async {
    final p = await showProjectDialog(context);
    if (p != null && context.mounted) {
      ref.invalidate(projectsProvider);
      context.go('/projects/${p.id}');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projects = ref.watch(projectsProvider);
    return PageFrame(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        PageHeader(
          title: 'Projects',
          subtitle: 'A project holds the videos and reports for one series or campaign.',
          actions: [
            FilledButton.icon(
              onPressed: () => _create(context, ref),
              icon: const Icon(Icons.add, size: 20),
              label: const Text('New project'),
            ),
          ],
        ),
        AsyncBody<Paged<Project>>(
          value: projects,
          onRetry: () => ref.invalidate(projectsProvider),
          data: (page) {
            if (page.items.isEmpty) {
              return EmptyState(
                title: 'No projects yet',
                body: 'Create a project, upload a short video, and get your first Viral Readiness Report.',
                actionLabel: 'Create your first project',
                onAction: () => _create(context, ref),
              );
            }
            return RowList(children: [for (final p in page.items) _ProjectRow(p)]);
          },
        ),
      ]),
    );
  }
}

class _ProjectRow extends StatelessWidget {
  final Project p;
  const _ProjectRow(this.p);

  @override
  Widget build(BuildContext context) {
    final meta = [if (p.platform != null) platformLabel(p.platform), if ((p.niche ?? '').isNotEmpty) p.niche!].join(', ');
    final count = p.analysisCount == 1 ? '1 analysis' : '${p.analysisCount} analyses';
    return InkWell(
      onTap: () => context.go('/projects/${p.id}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(p.name, style: display(19, weight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
              if (meta.isNotEmpty) Text(meta, style: const TextStyle(color: Tk.mute, fontSize: 14)),
            ]),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(count, style: const TextStyle(fontWeight: FontWeight.w600)),
            Text('Updated ${formatDateTime(p.updatedAt)}', style: const TextStyle(color: Tk.mute, fontSize: 12.5)),
          ]),
          const SizedBox(width: 8),
          const Icon(Icons.chevron_right, color: Tk.mute),
        ]),
      ),
    );
  }
}
