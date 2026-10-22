import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme.dart';
import '../util/text.dart';
import '../widgets/charts.dart';
import '../widgets/common.dart';
import '../widgets/fx.dart';

const _steps = [
  ('Drop your video', 'Pick a short video from your computer, up to 90 seconds. You can also paste a script instead.'),
  ('Pip watches it', 'This takes about 1 to 3 minutes. You can leave the page. A badge in the top bar shows where it is.'),
  ('Read your report', 'You get five scores, a list of fixes, and how ten pretend viewers reacted. Fix the first item, post, and come back.'),
];

const _faq = [
  ('Where do I find my report?', 'Open History in the left menu. Finished reports show a score. The top bar also shows any analysis that is still running.'),
  ('How long does an analysis take?', 'Usually 1 to 3 minutes. Longer videos can take a little more.'),
  ('Can I close the page while I wait?', 'Yes. The analysis keeps running. Open History later, or watch for the message that says it has finished.'),
  ('Why did my analysis not finish?', 'Sometimes the AI service is busy. Open the analysis and press Retry. If a video breaks the content rules it is blocked and deleted.'),
  ('Are the scores real predictions?', 'No. They are an AI\'s honest opinion of your video, not a promise about views.'),
  ('Is my video private?', 'Yes. Only you can open it. It is sent to an AI service to be analysed, and videos that break the rules are deleted.'),
];

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final ty = context.ty;
    return PageFrame(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        PageHeader(
          title: 'Help',
          subtitle: 'How ViralForge works, in plain words.',
          actions: [FilledButton.icon(onPressed: () => context.go('/new'), icon: const Icon(Icons.add, size: 20), label: const Text('Analyse a video'))],
        ),
        Reveal(
          child: SectionCard(
            title: 'How it works',
            child: Column(children: [
              for (var i = 0; i < _steps.length; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    CircleAvatar(radius: 16, backgroundColor: p.ultraSoft, child: Text('${i + 1}', style: TextStyle(color: p.ultra, fontWeight: FontWeight.w700))),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(_steps[i].$1, style: ty.bodyStrong),
                        Text(_steps[i].$2, style: ty.body.copyWith(color: p.mute)),
                      ]),
                    ),
                  ]),
                ),
            ]),
          ),
        ),
        const SizedBox(height: 16),
        Reveal(
          delayMs: 60,
          child: SectionCard(
            title: 'What the scores mean',
            subtitle: 'Every score is from 0 to 100. Higher is better.',
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              for (final e in skillHelp.entries)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${e.key[0].toUpperCase()}${e.key.substring(1)}', style: ty.bodyStrong),
                    Text(e.value, style: ty.body.copyWith(color: p.mute)),
                  ]),
                ),
              const Divider(),
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Overall', style: ty.bodyStrong),
                  Text('A mix of all four. 90 or more is exceptional, 75 is strong, 60 is promising, 40 is developing, and below 40 needs rework.',
                      style: ty.body.copyWith(color: p.mute)),
                ]),
              ),
            ]),
          ),
        ),
        const SizedBox(height: 16),
        Reveal(
          delayMs: 120,
          child: SectionCard(
            title: 'Common questions',
            child: Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: Column(children: [
                for (final q in _faq)
                  ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    childrenPadding: const EdgeInsets.only(bottom: 12),
                    expandedCrossAxisAlignment: CrossAxisAlignment.start,
                    title: Text(q.$1, style: ty.bodyStrong),
                    children: [Text(q.$2, style: ty.body.copyWith(color: p.mute))],
                  ),
              ]),
            ),
          ),
        ),
      ]),
    );
  }
}