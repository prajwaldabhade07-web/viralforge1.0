import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';

/// The signature element: a film strip of frames. Frames are accent-coloured up to the score and the
/// last filled frame is the sodium-yellow "playhead". Optional sprocket holes above and below.
class FrameStrip extends StatelessWidget {
  final double value; // 0-100
  final int cells;
  final double height;
  final bool animate;
  final bool perforated;
  final Color? trackColor;
  final Color? fillColor;
  final String? semanticLabel;

  const FrameStrip({
    super.key,
    required this.value,
    this.cells = 20,
    this.height = 16,
    this.animate = true,
    this.perforated = false,
    this.trackColor,
    this.fillColor,
    this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final reduce = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final animated = animate && !reduce;
    final v = value.clamp(0, 100).toDouble();
    return Semantics(
      label: semanticLabel ?? 'Score ${v.round()} out of 100',
      child: ExcludeSemantics(
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: animated ? 0 : v, end: v),
          duration: animated ? const Duration(milliseconds: 250) : Duration.zero,
          curve: Curves.easeOut,
          builder: (context, t, _) => SizedBox(
            height: height + (perforated ? 16 : 0),
            width: double.infinity,
            child: CustomPaint(
              painter: _StripPainter(
                value: t,
                cells: cells,
                track: trackColor ?? p.track,
                ultra: fillColor ?? p.ultra,
                sodium: p.sodium,
                hole: p.text.withValues(alpha: 0.22),
                perforated: perforated,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StripPainter extends CustomPainter {
  final double value;
  final int cells;
  final Color track;
  final Color ultra;
  final Color sodium;
  final Color hole;
  final bool perforated;
  _StripPainter({
    required this.value,
    required this.cells,
    required this.track,
    required this.ultra,
    required this.sodium,
    required this.hole,
    required this.perforated,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const gap = 3.0;
    final top = perforated ? 8.0 : 0.0;
    final ch = size.height - (perforated ? 16.0 : 0.0);
    final cw = (size.width - gap * (cells - 1)) / cells;
    if (cw <= 0 || ch <= 0) return;
    final filled = (value / 100 * cells).round().clamp(0, cells);
    final holePaint = Paint()..color = hole;
    for (var i = 0; i < cells; i++) {
      final rect = Rect.fromLTWH(i * (cw + gap), top, cw, ch);
      final color = i < filled - 1 ? ultra : (i == filled - 1 ? sodium : track);
      canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(2.5)), Paint()..color = color);
      if (perforated) {
        final hw = math.min(cw * 0.5, 8.0);
        canvas.drawRRect(
            RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(rect.center.dx, 3), width: hw, height: 3.5), const Radius.circular(1.5)),
            holePaint);
        canvas.drawRRect(
            RRect.fromRectAndRadius(
                Rect.fromCenter(center: Offset(rect.center.dx, size.height - 3), width: hw, height: 3.5), const Radius.circular(1.5)),
            holePaint);
      }
    }
  }

  @override
  bool shouldRepaint(_StripPainter old) =>
      old.value != value ||
      old.cells != cells ||
      old.track != track ||
      old.ultra != ultra ||
      old.sodium != sodium ||
      old.perforated != perforated;
}