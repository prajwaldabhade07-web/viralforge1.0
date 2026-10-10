import 'package:flutter/material.dart';

import '../models.dart';
import '../theme.dart';
import '../util/format.dart';
import 'common.dart';
import 'frame_strip.dart';

/// One analysis in a list (project page and history). Tappable.
class JobRow extends StatelessWidget {
  final Job job;
  final bool showProject;
  final VoidCallback onTap;
  const JobRow({super.key, required this.job, required this.onTap, this.showProject = false});

  @override
  Widget build(BuildContext context) {
    final title = showProject && (job.projectName ?? '').isNotEmpty
        ? job.projectName!
        : '${platformLabel(job.platform)}, ${job.niche}';
    final sub = showProject ? '${platformLabel(job.platform)}, ${job.niche}' : (job.caption ?? '');
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: LayoutBuilder(builder: (context, c) {
          final score = job.overall;
          final scoreBlock = SizedBox(
            width: 150,
            child: score == null
                ? StatusPill(job.status, blocked: job.isBlocked)
                : Row(children: [
                    Text('$score', style: display(26, height: 1)),
                    const SizedBox(width: 10),
                    Expanded(child: FrameStrip(value: score.toDouble(), cells: 10, height: 12, animate: false)),
                  ]),
          );
          final text = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: display(17, weight: FontWeight.w600)),
            if (sub.isNotEmpty)
              Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Tk.mute, fontSize: 14)),
            const SizedBox(height: 2),
            Text('${job.inputType == 'script' ? 'Script' : 'Video'} analysis, ${formatDateTime(job.createdAt)}',
                style: const TextStyle(color: Tk.mute, fontSize: 12.5)),
          ]);
          if (c.maxWidth < 520) {
            return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              text,
              const SizedBox(height: 10),
              scoreBlock,
            ]);
          }
          return Row(children: [
            Expanded(child: text),
            const SizedBox(width: 16),
            scoreBlock,
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, color: Tk.mute),
          ]);
        }),
      ),
    );
  }
}

/// A bordered list of rows separated by hairlines.
class RowList extends StatelessWidget {
  final List<Widget> children;
  const RowList({super.key, required this.children});

  @override
  Widget build(BuildContext context) => Panel(
        padding: EdgeInsets.zero,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(Tk.radius),
          child: Column(children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) const Divider(),
              children[i],
            ],
          ]),
        ),
      );
}
