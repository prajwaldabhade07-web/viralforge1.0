import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';

double _c01(double v) => v < 0 ? 0 : (v > 1 ? 1 : v);

/// Loading placeholder. Pulses gently; static when motion is off.
class Skeleton extends StatefulWidget {
  final double? width;
  final double height;
  final double radius;
  const Skeleton({super.key, this.width, this.height = 14, this.radius = 8});

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton> with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    if (Fx.enabled) _c.repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final box = DecoratedBox(
      decoration: BoxDecoration(color: p.track, borderRadius: BorderRadius.circular(widget.radius)),
      child: SizedBox(width: widget.width ?? double.infinity, height: widget.height),
    );
    if (!Fx.enabled) return box;
    return AnimatedBuilder(
      animation: _c,
      child: box,
      builder: (context, child) => Opacity(opacity: 0.55 + 0.45 * _c.value, child: child),
    );
  }
}

/// Counts up to [value]. Static when motion is off.
class CountUp extends StatelessWidget {
  final int value;
  final TextStyle style;
  const CountUp({super.key, required this.value, required this.style});

  @override
  Widget build(BuildContext context) {
    if (!Fx.enabled) return Text('$value', style: style);
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: value.toDouble()),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => Text('${v.round()}', style: style),
    );
  }
}

/// One-shot confetti. Reserved for scores of 75 and above.
class ConfettiBurst extends StatefulWidget {
  const ConfettiBurst({super.key});

  @override
  State<ConfettiBurst> createState() => _ConfettiBurstState();
}

class _ConfettiBurstState extends State<ConfettiBurst> with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2600));
    if (Fx.enabled) _c.forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!Fx.enabled) return const SizedBox.shrink();
    final p = context.pal;
    return CustomPaint(painter: _ConfettiPainter(_c, [p.ultra, p.sodium, kPink, kMint, p.onHero]), size: Size.infinite);
  }
}

class _Piece {
  final double vx, vy, rot, spin, delay, w, h;
  final Color color;
  const _Piece(this.vx, this.vy, this.rot, this.spin, this.delay, this.w, this.h, this.color);
}

class _ConfettiPainter extends CustomPainter {
  final Animation<double> t;
  final List<Color> colors;
  late final List<_Piece> _p = _make();
  _ConfettiPainter(this.t, this.colors) : super(repaint: t);

  List<_Piece> _make() {
    final rnd = math.Random(11);
    return List.generate(
        48,
        (i) => _Piece(rnd.nextDouble() * 1.2 - 0.3, 0.9 + rnd.nextDouble() * 0.8, rnd.nextDouble() * 6,
            rnd.nextDouble() * 10 - 5, rnd.nextDouble() * 0.15, 6 + rnd.nextDouble() * 4, 3 + rnd.nextDouble() * 3,
            colors[i % colors.length]));
  }

  @override
  void paint(Canvas canvas, Size size) {
    final o = Offset(size.width * 0.2, size.height * 0.55);
    for (final p in _p) {
      final u = _c01((t.value - p.delay) / (1 - p.delay));
      if (u <= 0) continue;
      final x = o.dx + p.vx * size.width * u;
      final y = o.dy + (-p.vy * u + 1.8 * u * u) * size.height * 0.9;
      final a = u < 0.7 ? 1.0 : 1 - (u - 0.7) / 0.3;
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(p.rot + p.spin * u);
      canvas.drawRect(Rect.fromCenter(center: Offset.zero, width: p.w, height: p.h),
          Paint()..color = p.color.withValues(alpha: _c01(a)));
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => false;
}