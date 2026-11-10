import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../theme.dart';

double _c01(double v) => v < 0 ? 0 : (v > 1 ? 1 : v);
double _lerp(double a, double b, double t) => a + (b - a) * t;

/// Maps [t] from the range [from]..[to] to 0..1 and applies [curve].
double _seg(double t, double from, double to, [Curve curve = Curves.linear]) =>
    curve.transform(_c01((t - from) / (to - from)));

/// "Report ready" moment. A big shaka hand rises from the bottom of the screen to the middle,
/// squeezes twice with a ripple, bursts into sparkles, and the report appears out of the blur.
///
/// Wrap the finished report in this widget. With [play] false (or when motion is switched off)
/// the report is shown at once. [play] is read once, when the widget is first built, so an
/// already-finished report that you open later never replays it. Tap anywhere to skip.
class ReportReveal extends StatefulWidget {
  final Widget child;
  final bool play;
  final VoidCallback? onDone;
  const ReportReveal({super.key, required this.child, this.play = false, this.onDone});

  @override
  State<ReportReveal> createState() => _ReportRevealState();
}

class _ReportRevealState extends State<ReportReveal> with SingleTickerProviderStateMixin {
  static const _total = Duration(milliseconds: 3800);
  late final AnimationController _c;
  bool _playing = false;

  @override
  void initState() {
    super.initState();
    _playing = widget.play && Fx.enabled;
    _c = AnimationController(vsync: this, duration: _total, value: _playing ? 0 : 1);
    if (_playing) {
      _c.forward().whenComplete(_finish);
    }
  }

  void _finish() {
    if (!mounted || !_playing) return;
    setState(() => _playing = false);
    widget.onDone?.call();
  }

  void _skip() {
    if (!_playing) return;
    _c.value = 1;
    _finish();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Respect the system "reduce motion" setting without changing the widget tree afterwards.
    if (_playing && (MediaQuery.maybeOf(context)?.disableAnimations ?? false)) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _skip());
    }
    return AnimatedBuilder(
      animation: _c,
      child: widget.child,
      builder: (context, child) {
        final t = _c.value;
        // The report comes in during the last part of the show: from soft blur to sharp.
        final reveal = _seg(t, 0.62, 1.0, Curves.easeOutCubic);
        final sigma = (1 - reveal) * 14;
        return Stack(fit: StackFit.expand, children: [
          IgnorePointer(
            ignoring: _playing && t < 0.9,
            child: Opacity(
              opacity: _playing ? reveal : 1,
              child: Transform.scale(
                scale: _playing ? _lerp(0.95, 1, reveal) : 1,
                child: ImageFiltered(
                  enabled: _playing && sigma > 0.2,
                  imageFilter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
                  child: child,
                ),
              ),
            ),
          ),
          if (_playing)
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _skip,
                child: Semantics(
                  label: 'Your report is ready. Tap to skip the animation.',
                  child: _Show(t: t),
                ),
              ),
            ),
        ]);
      },
    );
  }
}

class _Show extends StatelessWidget {
  final double t;
  const _Show({required this.t});

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final ty = context.ty;
    return LayoutBuilder(builder: (context, box) {
      final w = box.maxWidth;
      final h = box.maxHeight;
      final handW = math.min(w * 0.75, 320.0);
      final top = h * 0.26; // where the top of the hand ends up
      final boxH = h - top + 60; // the arm runs off the bottom of the screen

      // 0.00-0.28 rise · 0.28-0.58 two squeezes · 0.58-0.78 burst and fade out
      final rise = _seg(t, 0.0, 0.28, Curves.easeOutBack);
      final y = _lerp(h, top, rise);
      final squeezeT = _seg(t, 0.28, 0.58);
      final squeeze = math.sin(squeezeT * math.pi * 4).abs() * (squeezeT > 0 && squeezeT < 1 ? 1 : 0);
      final out = _seg(t, 0.58, 0.78, Curves.easeIn);
      final handScale = 1 + 0.10 * (1 - out) * math.sin(squeezeT * math.pi * 4).abs() + out * 0.35;
      final scrim = _seg(t, 0.0, 0.15) * (1 - _seg(t, 0.62, 0.95));
      final captionIn = _seg(t, 0.14, 0.30, Curves.easeOut) * (1 - _seg(t, 0.56, 0.68));

      final pivotY = ((0.6 * handW) / boxH) * 2 - 1; // the palm, whatever the arm length

      return Stack(children: [
        Positioned.fill(child: ColoredBox(color: Colors.black.withValues(alpha: 0.62 * scrim))),
        // Ripples at each squeeze.
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(painter: _RingsPainter(t: t, center: Offset(w / 2, top + handW * 0.55), color: p.ultra)),
          ),
        ),
        // The hand.
        Positioned(
          left: (w - handW) / 2,
          top: y,
          width: handW,
          height: boxH,
          child: Opacity(
            opacity: 1 - out,
            child: Transform(
              alignment: Alignment(0, pivotY),
              transform: Matrix4.diagonal3Values(
                handScale * (1 + 0.10 * squeeze),
                handScale * (1 - 0.12 * squeeze),
                1,
              ),
              child: CustomPaint(painter: _HandPainter(), size: Size(handW, boxH)),
            ),
          ),
        ),
        // Sparkle burst.
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(
              painter: _SparklePainter(t: _seg(t, 0.52, 0.95), center: Offset(w / 2, top + handW * 0.55), colors: [p.ultra, p.good, const Color(0xFFFFC857), Colors.white]),
            ),
          ),
        ),
        Positioned(
          left: 24,
          right: 24,
          top: top - 64,
          child: Opacity(
            opacity: captionIn,
            child: Text(
              'Your report is ready',
              textAlign: TextAlign.center,
              style: ty.title.copyWith(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800),
            ),
          ),
        ),
      ]);
    });
  }
}

/// A friendly shaka ("hang loose") hand drawn from rounded shapes. Design box is 300 wide;
/// the arm runs to the bottom of whatever height it is given.
class _HandPainter extends CustomPainter {
  static const _skin = Color(0xFFF6B680);
  static const _edge = Color(0xFF8C4C28);
  static const _shade = Color(0xFFE09664);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 300;
    canvas.save();
    canvas.scale(s);
    const ox = 50.0, oy = 30.0;
    final fill = Paint()..color = _skin;
    final line = Paint()
      ..color = _edge
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.2
      ..strokeJoin = StrokeJoin.round;

    void box(double l, double t, double r, double b, double rad) {
      final rr = RRect.fromLTRBR(l, t, r, b, Radius.circular(rad));
      canvas.drawRRect(rr, fill);
      canvas.drawRRect(rr, line);
    }

    void limb(double cx, double cy, double w, double len, double rad, double deg) {
      canvas.save();
      canvas.translate(cx, cy);
      canvas.rotate(deg * math.pi / 180);
      box(-w / 2, -len, w / 2, 0, rad);
      canvas.restore();
    }

    // Arm (to the bottom edge), thumb, pinky, palm, three curled fingers.
    box(ox + 58, oy + 190, ox + 142, size.height / s + 20, 10);
    canvas.drawRect(Rect.fromLTRB(ox + 58 + 62, oy + 200, ox + 142 - 3, size.height / s + 20), Paint()..color = _shade.withValues(alpha: 0.35));
    limb(ox + 62, oy + 178, 32, 84, 16, -62);
    limb(ox + 138, oy + 150, 28, 100, 14, 24);
    box(ox + 46, oy + 100, ox + 154, oy + 215, 40);
    for (final x in const [50.0, 83.0, 116.0]) {
      box(ox + x, oy + 84, ox + x + 34, oy + 150, 17);
    }
    for (final x in const [83.0, 116.0]) {
      canvas.drawLine(Offset(ox + x, oy + 120), Offset(ox + x, oy + 150), line..strokeWidth = 2.2);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _HandPainter old) => false;
}

class _RingsPainter extends CustomPainter {
  final double t;
  final Offset center;
  final Color color;
  _RingsPainter({required this.t, required this.center, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    // A ripple starts at each squeeze peak (t = 0.33 and 0.505).
    for (final start in const [0.33, 0.505]) {
      final q = _seg(t, start, start + 0.22, Curves.easeOut);
      if (q <= 0 || q >= 1) continue;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5 * (1 - q) + 1
        ..color = color.withValues(alpha: 0.65 * (1 - q));
      canvas.drawCircle(center, 60 + q * math.min(size.width, size.height) * 0.45, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _RingsPainter old) => old.t != t;
}

class _SparklePainter extends CustomPainter {
  final double t; // 0..1 for the burst only
  final Offset center;
  final List<Color> colors;
  _SparklePainter({required this.t, required this.center, required this.colors});

  @override
  void paint(Canvas canvas, Size size) {
    if (t <= 0 || t >= 1) return;
    const n = 36;
    final reach = math.max(size.width, size.height) * 0.42;
    for (var i = 0; i < n; i++) {
      // Fixed pseudo-random spread so every run looks the same.
      final a = i * 2.399963 + (i % 3) * 0.2;
      final speed = 0.45 + ((i * 37) % 100) / 100 * 0.75;
      final q = Curves.easeOutCubic.transform(t);
      final d = reach * speed * q;
      final pos = center + Offset(math.cos(a), math.sin(a)) * d + Offset(0, 40 * q * q * speed);
      final life = 1 - t;
      final r = (5 + (i % 4) * 3.0) * life;
      final paint = Paint()..color = colors[i % colors.length].withValues(alpha: _c01(life * 1.4));
      _star(canvas, pos, r, paint, t * 3 + i);
    }
  }

  void _star(Canvas canvas, Offset c, double r, Paint paint, double rot) {
    final path = Path();
    for (var k = 0; k < 8; k++) {
      final ang = rot + k * math.pi / 4;
      final rad = k.isEven ? r : r * 0.32;
      final pt = c + Offset(math.cos(ang), math.sin(ang)) * rad;
      if (k == 0) {
        path.moveTo(pt.dx, pt.dy);
      } else {
        path.lineTo(pt.dx, pt.dy);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _SparklePainter old) => old.t != t;
}
