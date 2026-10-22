import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';

/// Pip the panda peeking over a card. Eyes follow [look] (-1..1), paws cover the eyes at [cover] (0..1);
/// [peek] lowers the right paw so one eye can see (password shown).
class LoginPip extends StatelessWidget {
  final Offset look;
  final double cover;
  final double peek;
  final double size;
  const LoginPip({super.key, required this.look, this.cover = 0, this.peek = 0, this.size = 130});

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final d = Duration(milliseconds: Fx.enabled ? 180 : 0);
    return ExcludeSemantics(
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(end: cover),
        duration: d,
        curve: Curves.easeOut,
        builder: (context, c, _) => TweenAnimationBuilder<double>(
          tween: Tween<double>(end: peek),
          duration: d,
          builder: (context, pk, _) => TweenAnimationBuilder<Offset>(
            tween: Tween<Offset>(end: look),
            duration: Duration(milliseconds: Fx.enabled ? 120 : 0),
            builder: (context, l, _) => SizedBox(width: size, height: size, child: CustomPaint(painter: _PandaPainter(l, c, pk, p))),
          ),
        ),
      ),
    );
  }
}

class _PandaPainter extends CustomPainter {
  final Offset look;
  final double cover;
  final double peek;
  final Palette p;
  const _PandaPainter(this.look, this.cover, this.peek, this.p);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final ink = p.onSodium;
    final fur = p.onHero;
    Paint fill(Color c) => Paint()..color = c;
    Paint stroke(Color c, double w) => Paint()
      ..color = c
      ..style = PaintingStyle.stroke
      ..strokeWidth = w
      ..strokeCap = StrokeCap.round;
    canvas.translate(size.width / 2, size.height / 2);
    for (final sx in const [-1.0, 1.0]) {
      canvas.drawCircle(Offset(sx * s * 0.31, -s * 0.33), s * 0.13, fill(ink));
    }
    final head = Rect.fromCircle(center: Offset.zero, radius: s * 0.4);
    canvas.drawOval(head, fill(fur));
    canvas.drawOval(head, stroke(ink.withValues(alpha: 0.25), s * 0.015));
    for (final sx in const [-1.0, 1.0]) {
      final e = Offset(sx * s * 0.15, -s * 0.02);
      canvas.save();
      canvas.translate(e.dx, e.dy);
      canvas.rotate(sx * 0.35);
      canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: s * 0.15, height: s * 0.2), fill(ink));
      canvas.restore();
      canvas.drawCircle(e + Offset(look.dx * s * 0.02, look.dy * s * 0.02), s * 0.042, fill(fur));
      canvas.drawCircle(e + Offset(look.dx * s * 0.032, look.dy * s * 0.032), s * 0.019, fill(ink));
      canvas.drawCircle(Offset(sx * s * 0.28, s * 0.12), s * 0.05, fill(kPink.withValues(alpha: 0.5)));
    }
    canvas.drawOval(Rect.fromCenter(center: Offset(0, s * 0.1), width: s * 0.11, height: s * 0.075), fill(ink));
    canvas.drawArc(Rect.fromCenter(center: Offset(0, s * 0.17), width: s * 0.17, height: s * 0.09), 0.15, math.pi - 0.3, false, stroke(ink, s * 0.03));
    for (final sx in const [-1.0, 1.0]) {
      final c = sx < 0 ? cover : cover * (1 - peek);
      final pos = Offset.lerp(Offset(sx * s * 0.3, s * 0.5), Offset(sx * s * 0.15, -s * 0.02), c)!;
      final paw = Rect.fromCenter(center: pos, width: s * 0.22, height: s * 0.2);
      canvas.drawOval(paw, fill(ink));
      canvas.drawOval(paw, stroke(fur.withValues(alpha: 0.5), s * 0.012));
    }
  }

  @override
  bool shouldRepaint(_PandaPainter old) => old.look != look || old.cover != cover || old.peek != peek || old.p != p;
}

/// The cutting-room lamp. Pull the cord (drag it down), tap the lamp, or press any key to switch the room on.
class Lamp extends StatefulWidget {
  final bool lit;
  final VoidCallback onToggle;
  const Lamp({super.key, required this.lit, required this.onToggle});

  @override
  State<Lamp> createState() => _LampState();
}

class _LampState extends State<Lamp> {
  double _pull = 0;

  void _release() {
    final fire = _pull > 14;
    setState(() => _pull = 0);
    if (fire) widget.onToggle();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Semantics(
      button: true,
      label: widget.lit ? 'Turn the lamp off' : 'Pull the cord to turn the lamp on and sign in',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: widget.onToggle,
          onVerticalDragUpdate: (d) => setState(() => _pull = (_pull + d.delta.dy).clamp(0.0, 30.0).toDouble()),
          onVerticalDragEnd: (_) => _release(),
          onVerticalDragCancel: () => setState(() => _pull = 0),
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(end: widget.lit ? 1.0 : 0.0),
            duration: Duration(milliseconds: Fx.enabled ? 700 : 0),
            curve: Curves.easeOut,
            builder: (context, t, _) => Column(mainAxisSize: MainAxisSize.min, children: [
              CustomPaint(size: const Size(180, 250), painter: _LampPainter(t, p, _pull)),
              Opacity(
                opacity: 1 - t,
                child: Text('PULL THE CORD TO SIGN IN', textAlign: TextAlign.center, style: context.ty.caption.copyWith(fontSize: 11, letterSpacing: 1.2, color: p.heroMute)),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

class _LampPainter extends CustomPainter {
  final double t;
  final Palette p;
  final double pull;
  const _LampPainter(this.t, this.p, this.pull);

  @override
  void paint(Canvas canvas, Size size) {
    Paint fill(Color c) => Paint()..color = c;
    Paint line(Color c, double w) => Paint()
      ..color = c
      ..style = PaintingStyle.stroke
      ..strokeWidth = w
      ..strokeCap = StrokeCap.round;
    final cone = Path()
      ..moveTo(30, 112)
      ..lineTo(150, 112)
      ..lineTo(180, 248)
      ..lineTo(0, 248)
      ..close();
    canvas.drawPath(
        cone,
        Paint()
          ..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [p.sodium.withValues(alpha: 0.45 * t), p.sodium.withValues(alpha: 0)])
              .createShader(const Rect.fromLTWH(0, 112, 180, 136)));
    canvas.drawRect(const Rect.fromLTWH(86, 112, 8, 92), fill(p.heroMute.withValues(alpha: 0.6)));
    canvas.drawOval(const Rect.fromLTWH(55, 198, 70, 16), fill(p.heroMute.withValues(alpha: 0.6)));
    canvas.drawLine(const Offset(138, 110), Offset(138, 152 + pull), line(p.heroMute, 1.5));
    canvas.drawCircle(Offset(138, 156 + pull), 5, fill(Color.lerp(p.sodium, p.heroMute, t * 0.6)!));
    final shade = Path()
      ..moveTo(62, 40)
      ..lineTo(118, 40)
      ..lineTo(150, 112)
      ..lineTo(30, 112)
      ..close();
    canvas.drawPath(shade, fill(Color.lerp(p.heroTrack, p.sodium, t)!));
    final face = p.onSodium.withValues(alpha: 0.75);
    for (final x in const [72.0, 108.0]) {
      if (t > 0.5) {
        canvas.drawArc(Rect.fromCenter(center: Offset(x, 80), width: 14, height: 12), math.pi, math.pi, false, line(face, 2.5));
      } else {
        canvas.drawLine(Offset(x - 6, 78), Offset(x + 6, 78), line(p.heroMute, 2.5));
      }
    }
    canvas.drawArc(Rect.fromCenter(center: const Offset(90, 94), width: 18, height: 10), 0.2, math.pi - 0.4, false, line(t > 0.5 ? face : p.heroMute, 2.5));
  }

  @override
  bool shouldRepaint(_LampPainter old) => old.t != t || old.p != p || old.pull != pull;
}