import 'package:flutter/material.dart';

import '../theme.dart';

/// The signature element: a film strip of frames. Frames are ultramarine up to the score and the
/// last filled frame is the sodium-yellow "playhead". Animates in once; honours reduced motion.
class FrameStrip extends StatelessWidget {
  final double value; // 0-100
  final int cells;
  final double height;
  final bool animate;
  final Color trackColor;
  final String? semanticLabel;

  const FrameStrip({
    super.key,
    required this.value,
    this.cells = 20,
    this.height = 16,
    this.animate = true,
    this.trackColor = Tk.track,
    this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final animated = animate && !reduce;
    final v = value.clamp(0, 100).toDouble();
    return Semantics(
      label: semanticLabel ?? 'Score ${v.round()} out of 100',
      child: ExcludeSemantics(
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: animated ? 0 : v, end: v),
          duration: animated ? const Duration(milliseconds: 800) : Duration.zero,
          curve: Curves.easeOutCubic,
          builder: (context, t, _) => SizedBox(
            height: height,
            width: double.infinity,
            child: CustomPaint(painter: _StripPainter(t, cells, trackColor)),
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
  _StripPainter(this.value, this.cells, this.track);

  @override
  void paint(Canvas canvas, Size size) {
    const gap = 3.0;
    final cw = (size.width - gap * (cells - 1)) / cells;
    final filled = (value / 100 * cells).round().clamp(0, cells);
    for (var i = 0; i < cells; i++) {
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(i * (cw + gap), 0, cw, size.height),
        const Radius.circular(2.5),
      );
      final color = i < filled - 1 ? Tk.ultra : (i == filled - 1 ? Tk.sodium : track);
      canvas.drawRRect(rect, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(_StripPainter old) => old.value != value || old.cells != cells || old.track != track;
}
