import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../state/providers.dart' show ScorePoint;
import '../theme.dart';
import '../util/text.dart';
import 'common.dart';
import 'frame_strip.dart';
import 'fx.dart';
import 'pip.dart';

/// Titled card used by every dashboard block. [expand] fills a stretched parent.
class SectionCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Widget child;
  final bool expand;
  const SectionCard({super.key, required this.title, required this.child, this.subtitle, this.trailing, this.expand = false});

  @override
  Widget build(BuildContext context) {
    final ty = context.ty;
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
        children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: ty.heading, maxLines: 1, overflow: TextOverflow.ellipsis),
                if (subtitle != null) Text(subtitle!, style: ty.caption, maxLines: 2, overflow: TextOverflow.ellipsis),
              ]),
            ),
            if (trailing != null) trailing!,
          ]),
          const SizedBox(height: 14),
          if (expand) Expanded(child: child) else child,
        ],
      ),
    );
  }
}

/// KPI tile with a round arrow button. [filled] uses the accent gradient and shows [strip] as a film strip.
class KpiCard extends StatelessWidget {
  final String label;
  final int? value;
  final String note;
  final VoidCallback? onTap;
  final bool filled;
  final bool loading;
  final int tone; // 1 good, -1 bad, 0 neutral (note colour on white cards)
  final double? strip;
  const KpiCard({
    super.key,
    required this.label,
    required this.value,
    required this.note,
    this.onTap,
    this.filled = false,
    this.loading = false,
    this.tone = 0,
    this.strip,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final fg = filled ? p.onUltra : p.text;
    final sub = filled ? p.onUltra.withValues(alpha: 0.82) : p.mute;
    final noteColor = filled ? sub : (tone > 0 ? p.good : (tone < 0 ? p.bad : p.mute));
    final big = context.ty.title.copyWith(fontSize: 34, height: 1, color: fg);
    final v = value;
    return Container(
      height: 152,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: filled ? LinearGradient(colors: [p.ultra, p.ultraDeep], begin: Alignment.topLeft, end: Alignment.bottomRight) : null,
        color: filled ? null : p.surface,
        borderRadius: BorderRadius.circular(kRadius),
        border: filled ? null : Border.all(color: p.line),
        boxShadow: filled ? p.lift : null,
      ),
      child: loading
          ? const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Skeleton(width: 90),
              SizedBox(height: 14),
              Skeleton(width: 60, height: 32),
              Spacer(),
              Skeleton(width: 120, height: 12),
            ])
          : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.ty.bodyStrong.copyWith(fontSize: 14, color: sub))),
                _ArrowBtn(label: label, filled: filled, onTap: onTap),
              ]),
              const SizedBox(height: 6),
              v == null ? Text('-', style: big) : CountUp(value: v, style: big),
              if (strip != null) ...[
                const SizedBox(height: 8),
                FrameStrip(value: strip!, cells: 12, height: 10, fillColor: p.onUltra, trackColor: p.onUltra.withValues(alpha: 0.25)),
              ],
              const Spacer(),
              Text(note, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.ty.caption.copyWith(color: noteColor)),
            ]),
    );
  }
}

class _ArrowBtn extends StatelessWidget {
  final String label;
  final bool filled;
  final VoidCallback? onTap;
  const _ArrowBtn({required this.label, required this.filled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final fg = filled ? p.onUltra : p.text;
    return Semantics(
      button: true,
      label: 'Open $label',
      child: Material(
        color: filled ? p.onUltra.withValues(alpha: 0.2) : p.surfaceAlt,
        shape: CircleBorder(side: filled ? BorderSide.none : BorderSide(color: p.line)),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(width: 28, height: 28, child: Icon(Icons.arrow_outward, size: 15, color: onTap == null ? fg.withValues(alpha: 0.4) : fg)),
        ),
      ),
    );
  }
}

/// Pill bars: solid blue at 75+, the best bar in sodium yellow (two or more scores), the rest hatched grey.
/// Fills its parent unless [height] is given. Hover or tap a bar for its score.
class PillBars extends StatelessWidget {
  final List<ScorePoint> points;
  final int slots;
  final double? height;
  const PillBars({super.key, required this.points, this.slots = 7, this.height});

  Widget _bar(BuildContext context, ScorePoint? pt, int top) {
    final p = context.pal;
    final solid = pt != null && pt.score >= 75;
    final isTop = pt != null && pt.score == top;
    final frac = pt == null ? 0.28 : (pt.score / 100).clamp(0.14, 1.0).toDouble();
    final color = isTop ? p.sodium : Color.lerp(p.ultra.withValues(alpha: 0.7), p.ultra, ((pt?.score ?? 75) - 75) / 25)!;
    final msg = pt == null ? 'No analysis yet' : (pt.at == null ? '${pt.score}/100' : '${pt.score}/100, ${shortDate(pt.at)}');
    final pill = ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: (solid || isTop) ? ColoredBox(color: color) : CustomPaint(painter: _Hatch(p.line, p.surfaceAlt)),
    );
    return Column(children: [
      Expanded(
        child: Align(
          alignment: Alignment.bottomCenter,
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: Fx.enabled ? 0.001 : frac, end: frac),
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
            builder: (context, v, child) => FractionallySizedBox(heightFactor: v, widthFactor: 1, child: child),
            child: Tooltip(message: msg, triggerMode: TooltipTriggerMode.tap, child: pill),
          ),
        ),
      ),
      const SizedBox(height: 6),
      Text(shortDate(pt?.at), maxLines: 1, overflow: TextOverflow.clip, style: context.ty.caption.copyWith(fontSize: 11)),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final shown = points.length > slots ? points.sublist(points.length - slots) : points;
    final top = shown.length < 2 ? -1 : shown.map((e) => e.score).reduce(math.max);
    final bars = Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      for (var i = 0; i < slots; i++)
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 5),
            child: _bar(context, i >= slots - shown.length ? shown[i - (slots - shown.length)] : null, top),
          ),
        ),
    ]);
    return height == null ? bars : SizedBox(height: height, child: bars);
  }
}

class _Hatch extends CustomPainter {
  final Color line;
  final Color bg;
  const _Hatch(this.line, this.bg);

  @override
  void paint(Canvas canvas, Size s) {
    canvas.drawRect(Offset.zero & s, Paint()..color = bg);
    final paint = Paint()
      ..color = line
      ..strokeWidth = 1.5;
    for (var x = -s.height; x < s.width; x += 7) {
      canvas.drawLine(Offset(x, s.height), Offset(x + s.height, 0), paint);
    }
  }

  @override
  bool shouldRepaint(_Hatch old) => old.line != line || old.bg != bg;
}

/// The four skill scores of the latest report on film strips, with the strongest and weakest called out.
class SkillBars extends StatelessWidget {
  final Map<String, int> scores;
  const SkillBars({super.key, required this.scores});

  static const _labels = {'hook': 'Hook', 'engagement': 'Engagement', 'retention': 'Retention', 'shareability': 'Shareability'};

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final ty = context.ty;
    if (scores.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const PipMark(size: 64),
          Text('Your skills show up after your first report.', textAlign: TextAlign.center, style: ty.caption),
        ]),
      );
    }
    final hi = scores.values.reduce(math.max);
    final lo = scores.values.reduce(math.min);
    return Column(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
      for (final e in scores.entries)
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(_labels[e.key] ?? e.key, maxLines: 1, overflow: TextOverflow.ellipsis, style: ty.bodyStrong)),
            if (hi != lo && e.value == hi)
              _Tag('Strongest', p.good, p.goodSoft)
            else if (hi != lo && e.value == lo)
              _Tag('Needs work', p.warn, p.warnSoft),
            const SizedBox(width: 10),
            Text('${e.value}', style: ty.heading),
          ]),
          const SizedBox(height: 6),
          FrameStrip(value: e.value.toDouble(), cells: 20, height: 10, semanticLabel: '${_labels[e.key] ?? e.key} ${e.value} out of 100'),
        ]),
    ]);
  }
}

class _Tag extends StatelessWidget {
  final String text;
  final Color fg;
  final Color bg;
  const _Tag(this.text, this.fg, this.bg);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
        child: Text(text, style: TextStyle(color: fg, fontSize: 11.5, fontWeight: FontWeight.w700)),
      );
}