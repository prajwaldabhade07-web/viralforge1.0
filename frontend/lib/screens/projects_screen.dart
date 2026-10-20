import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models.dart';
import '../state/providers.dart';
import '../theme.dart';
import '../util/format.dart';
import '../util/studio.dart';
import '../widgets/common.dart';
import '../widgets/fx.dart';
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
            final items = page.items.where((p) => p.name != kQuickProject).toList();
            if (items.isEmpty) {
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
                for (var i = 0; i < items.length; i++)
                  SizedBox(width: w, child: Reveal(delayMs: 50 * i, child: Lift(child: _ProjectCard(p: items[i], index: i)))),
              ]);
            });
          },
        ),
      ]),
    );
  }
}

class _ProjectCard extends StatelessWidget {
  final Project p;
  final int index;
  const _ProjectCard({required this.p, required this.index});

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final ty = context.ty;
    final accents = [pal.ultra, kPink, kMint, pal.sodium];
    final accent = accents[index % accents.length];
    final meta = [if (p.platform != null) platformLabel(p.platform), if ((p.niche ?? '').isNotEmpty) p.niche!].join(', ');
    final count = p.analysisCount == 1 ? '1 analysis' : '${p.analysisCount} analyses';
    return Material(
      color: pal.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kRadius), side: BorderSide(color: pal.line)),
      child: InkWell(
        onTap: () => context.go('/projects/${p.id}'),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(color: accent.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(12)),
                child: Icon(Icons.movie_filter_outlined, color: pal.text),
              ),
              const Spacer(),
              Icon(Icons.arrow_outward, color: pal.mute, size: 20),
            ]),
            const SizedBox(height: 14),
            Text(p.name, style: ty.heading, maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            Text(meta.isEmpty ? 'No platform set' : meta, maxLines: 1, overflow: TextOverflow.ellipsis, style: ty.caption.copyWith(fontSize: 14)),
            const SizedBox(height: 14),
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: accent.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(20)),
                child: Text(count, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5, color: pal.text)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text('Updated ${formatDateTime(p.updatedAt)}',
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: ty.caption.copyWith(fontSize: 12.5)),
              ),
            ]),
          ]),
        ),
      ),
    );
  }
}