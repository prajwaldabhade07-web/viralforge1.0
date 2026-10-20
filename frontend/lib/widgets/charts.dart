import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../state/providers.dart' show ScorePoint;
import '../theme.dart';
import '../util/text.dart';
import 'common.dart';
import 'frame_strip.dart';
import 'fx.dart';

const _pad = 12.0;

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

  static const _days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

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
      Text(pt?.at == null ? '' : _days[pt!.at!.weekday - 1], style: context.ty.caption.copyWith(fontSize: 11)),
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

/// Half-donut gauge with the score and its verdict word. The sodium dot is the playhead.
class Gauge extends StatelessWidget {
  final int? score;
  final double? height;
  const Gauge({super.key, required this.score, this.height});

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final ty = context.ty;
    final sc = score;
    final t = (sc ?? 0) / 100;
    final big = ty.title.copyWith(fontSize: 40, height: 1);
    return Semantics(
      label: sc == null ? 'No score yet' : 'Latest score $sc out of 100, ${verdictFor(sc)}',
      child: SizedBox(
        width: double.infinity,
        height: height,
        child: Stack(alignment: Alignment.bottomCenter, children: [
          Positioned.fill(
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: Fx.enabled ? 0 : t, end: t),
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOut,
              builder: (context, v, _) => CustomPaint(painter: _GaugePainter(v, p.track, p.ultra, p.sodium, sc != null)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              sc == null ? Text('-', style: big) : CountUp(value: sc, style: big),
              Text(sc == null ? 'No score yet' : verdictFor(sc), style: ty.bodyStrong.copyWith(fontSize: 14)),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  final double t;
  final Color track;
  final Color fill;
  final Color dot;
  final bool has;
  const _GaugePainter(this.t, this.track, this.fill, this.dot, this.has);

  @override
  void paint(Canvas canvas, Size s) {
    const sw = 16.0;
    final r = math.min(s.width / 2, s.height) - sw / 2 - 2;
    if (r <= 0) return;
    final c = Offset(s.width / 2, s.height - sw / 2 - 2);
    final rect = Rect.fromCircle(center: c, radius: r);
    Paint stroke(Color color) => Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = sw
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, math.pi, math.pi, false, stroke(track));
    if (has && t > 0) {
      canvas.drawArc(rect, math.pi, math.pi * t, false, stroke(fill));
      final a = math.pi + math.pi * t;
      canvas.drawCircle(c + Offset(math.cos(a), math.sin(a)) * r, 4, Paint()..color = dot);
    }
  }

  @override
  bool shouldRepaint(_GaugePainter old) => old.t != t || old.track != track || old.fill != fill || old.has != has;
}

/// Score line with gradient fill, dashed previous period, and a hover/tap guide with tooltip.
class TrendLine extends StatefulWidget {
  final List<ScorePoint> points;
  final List<ScorePoint> prev;
  final double? height;
  const TrendLine({super.key, required this.points, this.prev = const [], this.height});

  @override
  State<TrendLine> createState() => _TrendLineState();
}

class _TrendLineState extends State<TrendLine> {
  int? _i;

  void _at(double dx) {
    final n = widget.points.length;
    final w = (context.size?.width ?? 0) - 2 * _pad;
    if (n < 2 || w <= 0) return;
    setState(() => _i = ((dx - _pad) / w * (n - 1)).round().clamp(0, n - 1).toInt());
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final ty = context.ty;
    final pts = widget.points;
    if (pts.length < 2) {
      return SizedBox(
        height: widget.height,
        child: Center(
          child: pts.isEmpty
              ? Text('Your trend shows up after your first report.', textAlign: TextAlign.center, style: ty.body.copyWith(color: p.mute))
              : Column(mainAxisSize: MainAxisSize.min, children: [
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    Text('${pts.first.score}', style: ty.score.copyWith(fontSize: 56)),
                    const SizedBox(width: 10),
                    Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(shape: BoxShape.circle, color: p.sodium, border: Border.all(color: p.ultra, width: 3)),
                    ),
                  ]),
                  Text('One more analysis unlocks your trend.', textAlign: TextAlign.center, style: ty.caption),
                ]),
        ),
      );
    }
    return Semantics(
      label: 'Score trend over your last ${pts.length} analyses',
      child: MouseRegion(
        onHover: (e) => _at(e.localPosition.dx),
        onExit: (_) => setState(() => _i = null),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (d) => _at(d.localPosition.dx),
          onHorizontalDragUpdate: (d) => _at(d.localPosition.dx),
          child: SizedBox(
            width: double.infinity,
            height: widget.height,
            child: CustomPaint(painter: _TrendPainter(pts, widget.prev, _i, p)),
          ),
        ),
      ),
    );
  }
}

void _dash(Canvas canvas, Path path, Paint paint) {
  for (final m in path.computeMetrics()) {
    for (var d = 0.0; d < m.length; d += 9) {
      canvas.drawPath(m.extractPath(d, math.min(d + 5, m.length)), paint);
    }
  }
}

class _TrendPainter extends CustomPainter {
  final List<ScorePoint> pts;
  final List<ScorePoint> prev;
  final int? hi;
  final Palette p;
  const _TrendPainter(this.pts, this.prev, this.hi, this.p);

  @override
  void paint(Canvas canvas, Size s) {
    final n = pts.length;
    final w = s.width - 2 * _pad;
    final h = s.height - 40;
    if (n < 2 || w <= 0 || h <= 0) return;
    Offset at(int i, int v) => Offset(_pad + w * i / (n - 1), 28 + h * (1 - v.clamp(0, 100) / 100));

    final grid = Paint()
      ..color = p.line
      ..strokeWidth = 1;
    for (final f in const [0.0, 0.5, 1.0]) {
      canvas.drawLine(Offset(_pad, 28 + h * f), Offset(_pad + w, 28 + h * f), grid);
    }

    final m = math.min(prev.length, n);
    if (m >= 2) {
      final d = Path();
      for (var j = 0; j < m; j++) {
        final o = at(n - m + j, prev[prev.length - m + j].score);
        if (j == 0) {
          d.moveTo(o.dx, o.dy);
        } else {
          d.lineTo(o.dx, o.dy);
        }
      }
      _dash(
          canvas,
          d,
          Paint()
            ..color = p.mute
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2);
    }

    final first = at(0, pts[0].score);
    final line = Path()..moveTo(first.dx, first.dy);
    for (var i = 1; i < n; i++) {
      final o = at(i, pts[i].score);
      line.lineTo(o.dx, o.dy);
    }
    final area = Path.from(line)
      ..lineTo(_pad + w, 28 + h)
      ..lineTo(_pad, 28 + h)
      ..close();
    canvas.drawPath(
        area,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [p.ultra.withValues(alpha: 0.3), p.ultra.withValues(alpha: 0)],
          ).createShader(Rect.fromLTWH(0, 28, s.width, h)));
    canvas.drawPath(
        line,
        Paint()
          ..color = p.ultra
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round);
    for (var i = 0; i < n - 1; i++) {
      canvas.drawCircle(at(i, pts[i].score), 3, Paint()..color = p.ultra);
    }
    final end = at(n - 1, pts[n - 1].score);
    canvas.drawCircle(end, 6, Paint()..color = p.ultra);
    canvas.drawCircle(end, 3.5, Paint()..color = p.sodium);

    final k = hi;
    if (k == null || k >= n) return;
    final o = at(k, pts[k].score);
    canvas.drawLine(
        Offset(o.dx, 22),
        Offset(o.dx, 28 + h),
        Paint()
          ..color = p.mute
          ..strokeWidth = 1.5);
    canvas.drawCircle(o, 6, Paint()..color = p.surface);
    canvas.drawCircle(
        o,
        6,
        Paint()
          ..color = p.ultra
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3);
    final d = shortDate(pts[k].at);
    final tp = TextPainter(
      text: TextSpan(text: d.isEmpty ? '${pts[k].score}' : '${pts[k].score}  $d', style: TextStyle(color: p.bg, fontSize: 12, fontWeight: FontWeight.w600)),
      textDirection: TextDirection.ltr,
    )..layout();
    final bw = tp.width + 16;
    final bh = tp.height + 10;
    final bx = (o.dx - bw / 2).clamp(2.0, math.max(2.0, s.width - bw - 2)).toDouble();
    final by = math.max(2.0, o.dy - bh - 10);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(bx, by, bw, bh), const Radius.circular(8)), Paint()..color = p.text);
    tp.paint(canvas, Offset(bx + 8, by + 5));
  }

  @override
  bool shouldRepaint(_TrendPainter old) => old.hi != hi || old.pts != pts || old.prev != prev || old.p != p;
}