import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme.dart';
import '../widgets/charts.dart';
import '../widgets/common.dart';
import '../widgets/fx.dart';
import 'quick_studio.dart';

const _checks = [
  'Up to 90 seconds, MP4, WebM or MOV.',
  'Vertical 9:16 works best for Reels, TikTok and Shorts.',
  'Put your hook in the first two seconds.',
  'Add on-screen text for people watching with the sound off.',
];

/// The New analysis page: Quick Studio at full size.
class NewScreen extends StatelessWidget {
  const NewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final ty = context.ty;
    final tips = SectionCard(
      title: 'Before you drop',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        for (final c in _checks)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Icons.check_circle_outline, size: 18, color: p.good),
              const SizedBox(width: 10),
              Expanded(child: Text(c, style: ty.body)),
            ]),
          ),
        const SizedBox(height: 10),
        Text('Want it filed under a project, or analyse a script only?', style: ty.caption),
        const SizedBox(height: 8),
        OutlinedButton(onPressed: () => context.go('/projects'), child: const Text('Open projects')),
      ]),
    );
    return PageFrame(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const PageHeader(title: 'New analysis', subtitle: 'Drop a clip and Pip takes it from here.'),
        Reveal(
          child: LayoutBuilder(builder: (context, c) {
            if (c.maxWidth > 760) {
              return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Expanded(flex: 3, child: QuickStudio()),
                const SizedBox(width: 14),
                Expanded(flex: 2, child: tips),
              ]);
            }
            return Column(children: [const QuickStudio(), const SizedBox(height: 14), tips]);
          }),
        ),
      ]),
    );
  }
}