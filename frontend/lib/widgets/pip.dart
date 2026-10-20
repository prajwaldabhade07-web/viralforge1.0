import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../theme.dart';

enum PipMood { idle, uploading, safety, analysing, personas, done, failed }

PipMood moodForStage(String status, String stage) {
  if (status == 'failed') return PipMood.failed;
  if (status == 'completed') return PipMood.done;
  switch (stage) {
    case 'preparing_video':
    case 'uploading':
      return PipMood.uploading;
    case 'moderating':
      return PipMood.safety;
    case 'analyzing':
      return PipMood.analysing;
    case 'simulating_audience':
    case 'finalizing':
      return PipMood.personas;
    default:
      return PipMood.idle;
  }
}

String moodCaption(PipMood m) {
  switch (m) {
    case PipMood.uploading:
      return 'Carrying your reel to the AI.';
    case PipMood.safety:
      return 'Stamping it through the safety check.';
    case PipMood.analysing:
      return 'Watching frame by frame, hook first.';
    case PipMood.personas:
      return 'Setting out ten chairs for your audience.';
    case PipMood.done:
      return 'Your report is ready.';
    case PipMood.failed:
      return 'The analysis stopped before it finished.';
    case PipMood.idle:
      return 'Warming up the projector.';
  }
}

class PipState {
  double t = 0.6;
  Offset look = Offset.zero;
  double jump = 0;
}

class PipPainter extends CustomPainter {
  final PipMood mood;
  final Palette p;
  final PipState? state;
  final bool stage;

  PipPainter({required this.mood, required this.p, this.state, this.stage = false, Listenable? repaint})
      : super(repaint: repaint);

  static const _white = Color(0xFFFFFFFF);
  static const _bandage = Color(0xFFF2D3A4);
  static const _cheek = Color(0xFFFF8FB1);

  Paint _fill(Color c) => Paint()..color = c;

  Paint _line(Color c, double w) => Paint()
    ..color = c
    ..style = PaintingStyle.stroke
    ..strokeWidth = w
    ..strokeCap = StrokeCap.round;

  @override
  void paint(Canvas canvas, Size size) {
    final t = state?.t ?? 0.6;
    final look = state?.look ?? Offset.zero;
    final jump = state?.jump ?? 0.0;
    final s = stage ? math.min(size.height * 0.42, size.width * 0.24) : math.min(size.width, size.height) * 0.62;
    final cx = size.width / 2;
    final cy = stage ? size.height * 0.55 : size.height * 0.58;
    if (stage) {
      _drawStage(canvas, size);
      if (mood == PipMood.personas) _drawChairs(canvas, size, t);
    }
    var lift = math.sin(math.pi * jump) * s * 0.4;
    if (mood == PipMood.done) lift += math.sin(t * 7).abs() * s * 0.16;
    if (stage) {
      final floorY = size.height * 0.80;
      final w = s * 0.9 * (1 - math.min(lift / (s * 0.6), 0.5));
      canvas.drawOval(Rect.fromCenter(center: Offset(cx, floorY + 4), width: w, height: 8),
          _fill(p.text.withValues(alpha: 0.12)));
    }
    final bob = math.sin(t * 2.4) * s * 0.02;
    canvas.save();
    canvas.translate(cx, cy + bob - lift);
    _drawPip(canvas, s, t, look);
    canvas.restore();
  }

  void _drawStage(Canvas canvas, Size size) {
    final r = RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(kRadius));
    canvas.drawRRect(r, _fill(p.surfaceAlt));
    final hole = _fill(p.line);
    for (var x = 14.0; x < size.width - 24; x += 22) {
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x, 8, 10, 6), const Radius.circular(2)), hole);
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x, size.height - 14, 10, 6), const Radius.circular(2)), hole);
    }
    final floorY = size.height * 0.80;
    canvas.drawLine(Offset(24, floorY), Offset(size.width - 24, floorY), _line(p.line, 2));
    canvas.drawRRect(r, _line(p.line, 1));
  }

  void _drawChairs(Canvas canvas, Size size, double t) {
    final floorY = size.height * 0.80;
    final scale = math.min(1.0, (size.width - 48) / 250);
    const n = 10;
    final cw = 20.0 * scale;
    final gap = 5.0 * scale;
    final total = n * cw + (n - 1) * gap;
    final x0 = (size.width - total) / 2;
    final visible = (t * 2.2).floor() % (n + 2);
    for (var i = 0; i < n && i < visible; i++) {
      final x = x0 + i * (cw + gap);
      final back = RRect.fromRectAndRadius(
          Rect.fromLTWH(x + cw * 0.1, floorY - cw * 1.25, cw * 0.8, cw * 0.7), Radius.circular(cw * 0.15));
      final seat = RRect.fromRectAndRadius(
          Rect.fromLTWH(x, floorY - cw * 0.55, cw, cw * 0.3), Radius.circular(cw * 0.1));
      canvas.drawRRect(back, _fill(p.ultra));
      canvas.drawRRect(seat, _fill(p.ultra));
    }
  }

  void _drawPip(Canvas canvas, double s, double t, Offset look) {
    final ink = p.onSodium;
    final bw = s * 0.8;
    final bh = s * 0.96;
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromCenter(center: Offset.zero, width: bw, height: bh), Radius.circular(s * 0.14)),
      _fill(p.sodium),
    );
    final holePaint = _fill(ink.withValues(alpha: 0.28));
    for (var i = 0; i < 4; i++) {
      final y = -bh / 2 + bh * (0.14 + 0.24 * i);
      canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromLTWH(-bw / 2 + s * 0.05, y, s * 0.07, s * 0.11), Radius.circular(s * 0.02)), holePaint);
      canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromLTWH(bw / 2 - s * 0.12, y, s * 0.07, s * 0.11), Radius.circular(s * 0.02)), holePaint);
    }

    final blink = (t % 4.2) < 0.13;
    for (final sx in const [-1.0, 1.0]) {
      final e = Offset(sx * s * 0.17, -s * 0.1);
      if (blink) {
        canvas.drawLine(e + Offset(-s * 0.07, 0), e + Offset(s * 0.07, 0), _line(ink, s * 0.03));
      } else {
        canvas.drawCircle(e, s * 0.1, _fill(_white));
        canvas.drawCircle(e + Offset(look.dx * s * 0.035, look.dy * s * 0.03), s * 0.05, _fill(ink));
      }
      if (mood == PipMood.failed) {
        canvas.drawLine(Offset(sx * s * 0.27, -s * 0.2), Offset(sx * s * 0.1, -s * 0.27), _line(ink, s * 0.03));
      } else {
        canvas.drawCircle(Offset(sx * s * 0.29, s * 0.08), s * 0.05, _fill(_cheek.withValues(alpha: 0.5)));
      }
    }

    final m = Offset(0, s * 0.16);
    if (mood == PipMood.safety) {
      canvas.drawLine(m + Offset(-s * 0.08, 0), m + Offset(s * 0.08, 0), _line(ink, s * 0.035));
    } else if (mood == PipMood.analysing) {
      canvas.drawCircle(m, s * 0.04, _line(ink, s * 0.03));
    } else if (mood == PipMood.failed) {
      canvas.drawArc(Rect.fromCenter(center: m + Offset(0, s * 0.05), width: s * 0.22, height: s * 0.12), math.pi,
          math.pi, false, _line(ink, s * 0.035));
    } else if (mood == PipMood.done) {
      canvas.drawArc(Rect.fromCenter(center: m, width: s * 0.3, height: s * 0.2), 0, math.pi, true, _fill(ink));
    } else {
      canvas.drawArc(Rect.fromCenter(center: m, width: s * 0.24, height: s * 0.14), 0.15, math.pi - 0.3, false,
          _line(ink, s * 0.035));
    }

    switch (mood) {
      case PipMood.uploading:
        _reel(canvas, s, t);
      case PipMood.safety:
        _stamp(canvas, s, t);
      case PipMood.analysing:
        _magnifier(canvas, s, t);
      case PipMood.done:
        _cheer(canvas, s, t);
      case PipMood.failed:
        _bandageMark(canvas, s);
      case PipMood.personas:
      case PipMood.idle:
        break;
    }
  }

  void _reel(Canvas canvas, double s, double t) {
    final ink = p.onSodium;
    final c = Offset(0, -s * 0.74);
    final r = s * 0.2;
    for (final sx in const [-1.0, 1.0]) {
      canvas.drawLine(Offset(sx * s * 0.4, -s * 0.05), Offset(sx * r * 0.9, -s * 0.62), _line(ink, s * 0.05));
    }
    canvas.drawCircle(c, r, _fill(p.ultra));
    canvas.drawCircle(c, r, _line(ink, s * 0.03));
    for (var i = 0; i < 3; i++) {
      final a = t * 3 + i * 2 * math.pi / 3;
      canvas.drawLine(c, c + Offset(math.cos(a), math.sin(a)) * r * 0.78, _line(_white, s * 0.035));
    }
    canvas.drawCircle(c, r * 0.18, _fill(_white));
  }

  void _stamp(Canvas canvas, double s, double t) {
    final ink = p.onSodium;
    final press = math.sin(t * 3.2) * 0.5 + 0.5;
    final doc = Rect.fromCenter(center: Offset(s * 0.82, s * 0.28), width: s * 0.42, height: s * 0.54);
    canvas.drawRRect(RRect.fromRectAndRadius(doc, Radius.circular(s * 0.04)), _fill(_white));
    canvas.drawRRect(RRect.fromRectAndRadius(doc, Radius.circular(s * 0.04)), _line(ink.withValues(alpha: 0.4), s * 0.015));
    for (var i = 0; i < 3; i++) {
      final y = doc.top + doc.height * (0.2 + 0.18 * i);
      canvas.drawLine(Offset(doc.left + s * 0.06, y), Offset(doc.right - s * 0.06, y), _line(p.line, s * 0.02));
    }
    if (press > 0.8) {
      final c = doc.center + Offset(0, doc.height * 0.2);
      final path = Path()
        ..moveTo(c.dx - s * 0.07, c.dy)
        ..lineTo(c.dx - s * 0.02, c.dy + s * 0.06)
        ..lineTo(c.dx + s * 0.09, c.dy - s * 0.06);
      canvas.drawPath(path, _line(p.good, s * 0.04));
    }
    final y = -s * 0.12 + press * s * 0.26;
    canvas.drawLine(Offset(s * 0.36, s * 0.05), Offset(s * 0.7, y - s * 0.16), _line(ink, s * 0.05));
    canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(s * 0.82, y - s * 0.14), width: s * 0.1, height: s * 0.2), Radius.circular(s * 0.04)),
        _fill(p.ultra));
    canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(s * 0.82, y + s * 0.02), width: s * 0.3, height: s * 0.08), Radius.circular(s * 0.03)),
        _fill(ink));
  }

  void _magnifier(Canvas canvas, double s, double t) {
    final ink = p.onSodium;
    final lens = Offset(s * 0.7 + math.sin(t * 2) * s * 0.12, s * 0.02);
    final r = s * 0.2;
    canvas.drawLine(Offset(s * 0.36, s * 0.12), lens + Offset(-r * 0.7, r * 0.7), _line(ink, s * 0.05));
    canvas.drawLine(lens + Offset(r * 0.7, r * 0.7), lens + Offset(r * 1.4, r * 1.4), _line(ink, s * 0.06));
    canvas.drawCircle(lens, r, _fill(_white.withValues(alpha: 0.65)));
    canvas.drawCircle(lens, r, _line(ink, s * 0.04));
  }

  void _cheer(Canvas canvas, double s, double t) {
    final ink = p.onSodium;
    final w = math.sin(t * 9) * s * 0.05;
    for (final sx in const [-1.0, 1.0]) {
      canvas.drawLine(Offset(sx * s * 0.4, -s * 0.02), Offset(sx * s * 0.62, -s * 0.5 + w), _line(ink, s * 0.05));
      canvas.drawCircle(Offset(sx * s * 0.62, -s * 0.54 + w), s * 0.05, _fill(ink));
    }
    final sp = _fill(p.ultra);
    for (var i = 0; i < 3; i++) {
      final a = t * 2 + i * 2.1;
      canvas.drawCircle(Offset(math.cos(a) * s * 0.75, -s * 0.7 + math.sin(a * 1.3) * s * 0.18), s * 0.03, sp);
    }
  }

  void _bandageMark(Canvas canvas, double s) {
    canvas.save();
    canvas.translate(s * 0.14, -s * 0.34);
    canvas.rotate(-0.5);
    final r = RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset.zero, width: s * 0.36, height: s * 0.13), Radius.circular(s * 0.04));
    canvas.drawRRect(r, _fill(_bandage));
    canvas.drawRRect(r, _line(p.onSodium.withValues(alpha: 0.35), s * 0.012));
    final dot = _fill(p.onSodium.withValues(alpha: 0.35));
    for (final dx in const [-0.07, 0.0, 0.07]) {
      canvas.drawCircle(Offset(dx * s, 0), s * 0.012, dot);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(PipPainter old) => old.mood != mood || old.p != p || old.stage != stage;
}

/// Static Pip for empty states and the sidebar.
class PipMark extends StatelessWidget {
  final PipMood mood;
  final double size;
  const PipMark({super.key, this.mood = PipMood.idle, this.size = 64});

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
        child: SizedBox(
          width: size,
          height: size,
          child: CustomPaint(painter: PipPainter(mood: mood, p: context.pal)),
        ),
      );
}

/// Pip's booth: one Ticker, one RepaintBoundary. Pip follows the cursor only inside the booth and jumps on a click or tap.
/// Pauses when the tab is hidden and stays still when the system asks for reduced motion.
class PipBooth extends StatefulWidget {
  final PipMood mood;
  final double height;
  const PipBooth({super.key, required this.mood, this.height = 220});

  @override
  State<PipBooth> createState() => _PipBoothState();
}

class _PipBoothState extends State<PipBooth> with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final PipState _s = PipState();
  final ValueNotifier<int> _repaint = ValueNotifier<int>(0);
  late final Ticker _ticker;
  Duration _last = Duration.zero;
  bool _reduce = false;
  bool _hidden = false;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduce = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    _sync();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _hidden = state != AppLifecycleState.resumed;
    _sync();
  }

  void _sync() {
    final run = Fx.enabled && !_reduce && !_hidden;
    if (run) {
      if (!_ticker.isActive) {
        _last = Duration.zero;
        _ticker.start();
      }
    } else if (_ticker.isActive) {
      _ticker.stop();
    }
  }

  void _onTick(Duration elapsed) {
    final dt = ((elapsed - _last).inMicroseconds / 1000000.0).clamp(0.0, 0.05).toDouble();
    _last = elapsed;
    _s.t += dt;
    if (_s.jump > 0) _s.jump = math.max(0, _s.jump - dt * 2.0);
    _repaint.value++;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker.dispose();
    _repaint.dispose();
    super.dispose();
  }

  void _look(Offset pos, Size size) {
    _s.look = Offset(((pos.dx - size.width / 2) / (size.width / 2)).clamp(-1.0, 1.0).toDouble(),
        ((pos.dy - size.height / 2) / (size.height / 2)).clamp(-1.0, 1.0).toDouble());
    _repaint.value++;
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Semantics(
      label: 'Pip. ${moodCaption(widget.mood)}',
      child: LayoutBuilder(builder: (context, c) {
        final size = Size(c.maxWidth, widget.height);
        return MouseRegion(
          onHover: (e) => _look(e.localPosition, size),
          onExit: (_) {
            _s.look = Offset.zero;
            _repaint.value++;
          },
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              if (_ticker.isActive) _s.jump = 1;
            },
            child: RepaintBoundary(
              child: SizedBox(
                height: widget.height,
                width: double.infinity,
                child: CustomPaint(
                  painter: PipPainter(mood: widget.mood, p: p, state: _s, stage: true, repaint: _repaint),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}