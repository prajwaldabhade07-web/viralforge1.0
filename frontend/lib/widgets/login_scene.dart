import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';

/// Pip peeking over a card. Eyes follow [look] (-1..1), paws cover the eyes at [cover] (0..1);
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
            builder: (context, l, _) => SizedBox(width: size, height: size, child: CustomPaint(painter: _PipPainter(l, c, pk, p))),
          ),
        ),
      ),
    );
  }
}

class _PipPainter extends CustomPainter {
  final Offset look;
  final double cover;
  final double peek;
  final Palette p;
  const _PipPainter(this.look, this.cover, this.peek, this.p);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final ink = p.onSodium;
    Paint fill(Color c) => Paint()..color = c;
    canvas.translate(size.width / 2, size.height / 2);
    final bw = s * 0.74;
    final bh = s * 0.86;
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset.zero, width: bw, height: bh), Radius.circular(s * 0.14)), fill(p.sodium));
    final hole = fill(ink.withValues(alpha: 0.28));
    for (var i = 0; i < 4; i++) {
      final y = -bh / 2 + bh * (0.14 + 0.24 * i);
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(-bw / 2 + s * 0.05, y, s * 0.07, s * 0.11), Radius.circular(s * 0.02)), hole);
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(bw / 2 - s * 0.12, y, s * 0.07, s * 0.11), Radius.circular(s * 0.02)), hole);
    }
    for (final sx in const [-1.0, 1.0]) {
      final e = Offset(sx * s * 0.17, -s * 0.12);
      canvas.drawCircle(e, s * 0.11, fill(p.onHero));
      canvas.drawCircle(e + Offset(look.dx * s * 0.045, look.dy * s * 0.04), s * 0.055, fill(ink));
      canvas.drawCircle(Offset(sx * s * 0.29, s * 0.1), s * 0.05, fill(kPink.withValues(alpha: 0.5)));
    }
    canvas.drawArc(
      Rect.fromCenter(center: Offset(0, s * 0.17), width: s * 0.24, height: s * 0.14),
      0.15,
      math.pi - 0.3,
      false,
      Paint()
        ..color = ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.035
        ..strokeCap = StrokeCap.round,
    );
    for (final sx in const [-1.0, 1.0]) {
      final c = sx < 0 ? cover : cover * (1 - peek);
      final pos = Offset.lerp(Offset(sx * s * 0.30, s * 0.50), Offset(sx * s * 0.17, -s * 0.12), c)!;
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: pos, width: s * 0.27, height: s * 0.2), Radius.circular(s * 0.09)), fill(ink));
    }
  }

  @override
  bool shouldRepaint(_PipPainter old) => old.look != look || old.cover != cover || old.peek != peek || old.p != p;
}

/// The cutting-room lamp. Tap it (or flick the cord down) to switch the room on or off.
class Lamp extends StatelessWidget {
  final bool lit;
  final VoidCallback onToggle;
  const Lamp({super.key, required this.lit, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Semantics(
      button: true,
      label: lit ? 'Turn the lamp off' : 'Turn the lamp on',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onToggle,
          onVerticalDragEnd: (d) {
            if ((d.primaryVelocity ?? 0) > 150) onToggle();
          },
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(end: lit ? 1.0 : 0.0),
            duration: Duration(milliseconds: Fx.enabled ? 250 : 0),
            builder: (context, t, _) => Column(mainAxisSize: MainAxisSize.min, children: [
              CustomPaint(size: const Size(180, 250), painter: _LampPainter(t, p)),
              Opacity(opacity: 1 - t, child: Text('PULL THE CORD', style: context.ty.caption.copyWith(fontSize: 11, letterSpacing: 1.2, color: p.heroMute))),
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
  const _LampPainter(this.t, this.p);

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
          ..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [p.sodium.withValues(alpha: 0.38 * t), p.sodium.withValues(alpha: 0)])
              .createShader(const Rect.fromLTWH(0, 112, 180, 136)));
    canvas.drawRect(const Rect.fromLTWH(86, 112, 8, 92), fill(p.heroMute.withValues(alpha: 0.6)));
    canvas.drawOval(const Rect.fromLTWH(55, 198, 70, 16), fill(p.heroMute.withValues(alpha: 0.6)));
    canvas.drawLine(const Offset(138, 110), const Offset(138, 152), line(p.heroMute, 1.5));
    canvas.drawCircle(const Offset(138, 156), 4, fill(Color.lerp(p.heroMute, p.sodium, t)!));
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
  bool shouldRepaint(_LampPainter old) => old.t != t || old.p != p;
}