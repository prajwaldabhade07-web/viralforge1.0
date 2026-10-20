import 'dart:math' as math;

import 'package:flutter/material.dart';

class _SprocketPainter extends CustomPainter {
  final Color color;
  const _SprocketPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    const hole = 6.0;
    const w = hole * 1.7;
    const gap = hole * 2.1;
    for (var x = 14.0; x < size.width - 14 - w; x += w + gap) {
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x, 6, w, hole), const Radius.circular(2)), paint);
      canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromLTWH(x, size.height - 6 - hole, w, hole), const Radius.circular(2)), paint);
    }
  }

  @override
  bool shouldRepaint(_SprocketPainter old) => old.color != color;
}

/// Sprocket holes along the top and bottom edge. Use as a direct child of a Stack.
class SprocketOverlay extends StatelessWidget {
  final Color color;
  const SprocketOverlay({super.key, required this.color});

  @override
  Widget build(BuildContext context) =>
      Positioned.fill(child: IgnorePointer(child: CustomPaint(painter: _SprocketPainter(color))));
}

class _GrainPainter extends CustomPainter {
  final Color color;
  const _GrainPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final rnd = math.Random(5);
    final paint = Paint()..color = color;
    final n = (size.width * size.height / 900).clamp(80, 700).toInt();
    for (var i = 0; i < n; i++) {
      canvas.drawRect(Rect.fromLTWH(rnd.nextDouble() * size.width, rnd.nextDouble() * size.height, 1.2, 1.2), paint);
    }
  }

  @override
  bool shouldRepaint(_GrainPainter old) => old.color != color;
}

/// Subtle static film grain. Hero areas only. Use as a direct child of a Stack.
class GrainOverlay extends StatelessWidget {
  final Color color;
  const GrainOverlay({super.key, required this.color});

  @override
  Widget build(BuildContext context) =>
      Positioned.fill(child: IgnorePointer(child: RepaintBoundary(child: CustomPaint(painter: _GrainPainter(color)))));
}
