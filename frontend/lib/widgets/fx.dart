import 'dart:math' as math;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../theme.dart';

double _c01(double v) => v < 0 ? 0 : (v > 1 ? 1 : v);

// ───────────────────────── Cursor glow, sparkle trail, click bursts ─────────────────────────

class CursorFx extends StatelessWidget {
  final Widget child;
  const CursorFx({super.key, required this.child});

  @override
  Widget build(BuildContext context) => (Fx.enabled && kIsWeb) ? _CursorLayer(child: child) : child;
}

class _Dot {
  final Offset pos;
  final int c;
  double life = 1;
  _Dot(this.pos, this.c);
}

class _Burst {
  final Offset pos;
  double t = 0;
  final double seed = math.Random().nextDouble() * 6;
  _Burst(this.pos);
}

class _CursorLayer extends StatefulWidget {
  final Widget child;
  const _CursorLayer({required this.child});

  @override
  State<_CursorLayer> createState() => _CursorLayerState();
}

class _CursorLayerState extends State<_CursorLayer> with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final ValueNotifier<int> _repaint = ValueNotifier<int>(0);
  final List<_Dot> _dots = [];
  final List<_Burst> _bursts = [];
  Duration _last = Duration.zero;
  Offset? _target;
  Offset _ring = Offset.zero;
  Offset _lastSpawn = Offset.zero;
  int _colorIx = 0;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_tick);
  }

  void _ensure() {
    if (!_ticker.isActive) {
      _last = Duration.zero;
      _ticker.start();
    }
  }

  void _tick(Duration elapsed) {
    final dt = ((elapsed - _last).inMicroseconds / 1000000.0).clamp(0.0, 0.05).toDouble();
    _last = elapsed;
    final t = _target;
    if (t != null) {
      final k = 1 - math.exp(-16 * dt);
      _ring = Offset.lerp(_ring, t, k)!;
    }
    for (final d in _dots) {
      d.life -= dt * 2.4;
    }
    _dots.removeWhere((d) => d.life <= 0);
    for (final b in _bursts) {
      b.t += dt * 1.6;
    }
    _bursts.removeWhere((b) => b.t >= 1);
    _repaint.value++;
    final settled = t == null || (_ring - t).distance < 0.5;
    if (_dots.isEmpty && _bursts.isEmpty && settled) _ticker.stop();
  }

  void _move(Offset p) {
    if (_target == null) _ring = p;
    _target = p;
    if ((p - _lastSpawn).distance > 16) {
      _lastSpawn = p;
      _dots.add(_Dot(p, _colorIx++ % 4));
      if (_dots.length > 14) _dots.removeAt(0);
    }
    _ensure();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _repaint.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) return widget.child;
    return MouseRegion(
      onHover: (e) => _move(e.localPosition),
      onExit: (_) {
        _target = null;
        _ensure();
      },
      child: Listener(
        onPointerMove: (e) => _move(e.localPosition),
        onPointerDown: (e) {
          _bursts.add(_Burst(e.localPosition));
          _ensure();
        },
        child: Stack(children: [
          Positioned.fill(child: widget.child),
          Positioned.fill(child: IgnorePointer(child: CustomPaint(painter: _CursorPainter(this)))),
        ]),
      ),
    );
  }
}

class _CursorPainter extends CustomPainter {
  final _CursorLayerState s;
  _CursorPainter(this.s) : super(repaint: s._repaint);
  static const _cols = [Tk.ultra, Tk.pink, Tk.sodium, Tk.mint];

  @override
  void paint(Canvas canvas, Size size) {
    for (final d in s._dots) {
      final l = _c01(d.life);
      canvas.drawCircle(d.pos, 2 + 4 * l, Paint()..color = _cols[d.c].withOpacity(l * 0.75));
    }
    final t = s._target;
    if (t != null) {
      final r = s._ring;
      final glow = Paint()
        ..shader = RadialGradient(colors: [Tk.ultra.withOpacity(0.16), Tk.ultra.withOpacity(0)])
            .createShader(Rect.fromCircle(center: r, radius: 64));
      canvas.drawCircle(r, 64, glow);
      canvas.drawCircle(
          r,
          15,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5
            ..color = Tk.ultra.withOpacity(0.55));
      canvas.drawCircle(t, 3, Paint()..color = Tk.ultra);
    }
    for (final b in s._bursts) {
      final p = _c01(b.t);
      final e = Curves.easeOutCubic.transform(p);
      final a = 1 - p;
      canvas.drawCircle(
          b.pos,
          8 + 46 * e,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = Tk.pink.withOpacity(a * 0.7));
      for (var i = 0; i < 8; i++) {
        final ang = i * math.pi / 4 + b.seed;
        final o = b.pos + Offset(math.cos(ang), math.sin(ang)) * (14 + 52 * e);
        canvas.drawCircle(o, 3 * a + 0.5, Paint()..color = _cols[i % 4].withOpacity(a));
      }
    }
  }

  @override
  bool shouldRepaint(_CursorPainter old) => false;
}

// ───────────────────────── Entrance animation ─────────────────────────

class Reveal extends StatefulWidget {
  final Widget child;
  final int delayMs;
  final double dy;
  const Reveal({super.key, required this.child, this.delayMs = 0, this.dy = 18});

  @override
  State<Reveal> createState() => _RevealState();
}

class _RevealState extends State<Reveal> with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<double> _a;

  @override
  void initState() {
    super.initState();
    final total = 520 + widget.delayMs;
    _c = AnimationController(vsync: this, duration: Duration(milliseconds: total));
    _a = CurvedAnimation(parent: _c, curve: Interval(widget.delayMs / total, 1, curve: Curves.easeOutCubic));
    if (Fx.enabled) {
      _c.forward();
    } else {
      _c.value = 1;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!Fx.enabled) return widget.child;
    return AnimatedBuilder(
      animation: _a,
      child: widget.child,
      builder: (context, child) => Opacity(
        opacity: _c01(_a.value),
        child: Transform.translate(offset: Offset(0, (1 - _a.value) * widget.dy), child: child),
      ),
    );
  }
}

// ───────────────────────── Hover lift ─────────────────────────

class HoverLift extends StatefulWidget {
  final Widget child;
  final double radius;
  const HoverLift({super.key, required this.child, this.radius = 14});

  @override
  State<HoverLift> createState() => _HoverLiftState();
}

class _HoverLiftState extends State<HoverLift> {
  bool _h = false;

  @override
  Widget build(BuildContext context) {
    if (!Fx.enabled) return widget.child;
    return MouseRegion(
      onEnter: (_) => setState(() => _h = true),
      onExit: (_) => setState(() => _h = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        transform: Matrix4.translationValues(0, _h ? -4 : 0, 0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(widget.radius),
          boxShadow: _h
              ? [BoxShadow(color: Tk.ultra.withOpacity(0.16), blurRadius: 26, offset: const Offset(0, 12))]
              : const [],
        ),
        child: widget.child,
      ),
    );
  }
}

// ───────────────────────── Floating colour blobs ─────────────────────────

class AmbientBlobs extends StatefulWidget {
  final List<Color> colors;
  final double opacity;
  const AmbientBlobs({super.key, required this.colors, this.opacity = 0.5});

  @override
  State<AmbientBlobs> createState() => _AmbientBlobsState();
}

class _AmbientBlobsState extends State<AmbientBlobs> with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(seconds: 16));
    if (Fx.enabled) _c.repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!Fx.enabled) return const SizedBox.shrink();
    return IgnorePointer(
      child: CustomPaint(painter: _BlobPainter(_c, widget.colors, widget.opacity), size: Size.infinite),
    );
  }
}

class _BlobPainter extends CustomPainter {
  final Animation<double> t;
  final List<Color> colors;
  final double opacity;
  _BlobPainter(this.t, this.colors, this.opacity) : super(repaint: t);

  @override
  void paint(Canvas canvas, Size size) {
    final r = math.max(size.width, size.height) * 0.34;
    for (var i = 0; i < colors.length; i++) {
      final phase = t.value * 2 * math.pi + i * 2.1;
      final cx = size.width * (0.2 + 0.6 * (i + 1) / (colors.length + 1)) + math.cos(phase) * size.width * 0.08;
      final cy = size.height * (0.3 + 0.4 * (i % 2)) + math.sin(phase * 1.3) * size.height * 0.12;
      final paint = Paint()
        ..shader = RadialGradient(colors: [colors[i].withOpacity(opacity), colors[i].withOpacity(0)])
            .createShader(Rect.fromCircle(center: Offset(cx, cy), radius: r));
      canvas.drawCircle(Offset(cx, cy), r, paint);
    }
  }

  @override
  bool shouldRepaint(_BlobPainter old) => false;
}

// ───────────────────────── Gentle bobbing ─────────────────────────

class Bob extends StatefulWidget {
  final Widget child;
  final double dy;
  final double phase;
  const Bob({super.key, required this.child, this.dy = 6, this.phase = 0});

  @override
  State<Bob> createState() => _BobState();
}

class _BobState extends State<Bob> with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 3200));
    if (Fx.enabled) _c.repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!Fx.enabled) return widget.child;
    return AnimatedBuilder(
      animation: _c,
      child: widget.child,
      builder: (context, child) => Transform.translate(
        offset: Offset(0, math.sin((_c.value + widget.phase) * 2 * math.pi) * widget.dy),
        child: child,
      ),
    );
  }
}

// ───────────────────────── Count-up number ─────────────────────────

class CountUp extends StatelessWidget {
  final int value;
  final TextStyle style;
  const CountUp({super.key, required this.value, required this.style});

  @override
  Widget build(BuildContext context) {
    if (!Fx.enabled) return Text('$value', style: style);
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: value.toDouble()),
      duration: const Duration(milliseconds: 1100),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => Text('${v.round()}', style: style),
    );
  }
}

// ───────────────────────── Confetti (one shot) ─────────────────────────

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
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2800));
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
    return CustomPaint(painter: _ConfettiPainter(_c), size: Size.infinite);
  }
}

class _Piece {
  final double vx, vy, rot, spin, delay, w, h;
  final Color color;
  const _Piece(this.vx, this.vy, this.rot, this.spin, this.delay, this.w, this.h, this.color);
}

class _ConfettiPainter extends CustomPainter {
  final Animation<double> t;
  late final List<_Piece> _p = _make();
  _ConfettiPainter(this.t) : super(repaint: t);

  List<_Piece> _make() {
    final rnd = math.Random(11);
    const cols = [Tk.ultra, Tk.sodium, Tk.pink, Tk.mint, Colors.white];
    return List.generate(
        48,
        (i) => _Piece(rnd.nextDouble() * 1.2 - 0.3, 0.9 + rnd.nextDouble() * 0.8, rnd.nextDouble() * 6,
            rnd.nextDouble() * 10 - 5, rnd.nextDouble() * 0.15, 6 + rnd.nextDouble() * 4, 3 + rnd.nextDouble() * 3,
            cols[i % cols.length]));
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
          Paint()..color = p.color.withOpacity(_c01(a)));
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => false;
}

// ───────────────────────── Film-strip loader ─────────────────────────

class FilmLoader extends StatefulWidget {
  final int cells;
  final double height;
  const FilmLoader({super.key, this.cells = 16, this.height = 18});

  @override
  State<FilmLoader> createState() => _FilmLoaderState();
}

class _FilmLoaderState extends State<FilmLoader> with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2400));
    if (Fx.enabled) _c.repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
        height: widget.height,
        width: double.infinity,
        child: CustomPaint(painter: _FilmPainter(_c, widget.cells)),
      );
}

class _FilmPainter extends CustomPainter {
  final Animation<double> t;
  final int cells;
  _FilmPainter(this.t, this.cells) : super(repaint: t);

  @override
  void paint(Canvas canvas, Size size) {
    const gap = 4.0;
    final cw = (size.width - gap * (cells - 1)) / cells;
    if (cw <= 0) return;
    final head = (t.value * cells).floor() % cells;
    for (var i = 0; i < cells; i++) {
      final dist = (head - i) % cells;
      final Color color;
      if (dist == 0) {
        color = Tk.sodium;
      } else if (dist <= 3) {
        color = Tk.ultra.withOpacity(1 - dist * 0.22);
      } else {
        color = Tk.track;
      }
      canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromLTWH(i * (cw + gap), 0, cw, size.height), const Radius.circular(3)),
          Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(_FilmPainter old) => false;
}