import 'package:flutter/material.dart';

import '../theme.dart';

/// Input style for the dark "cutting room" screens (sign-in, welcome, password reset).
InputDecoration darkField(BuildContext context, String label, {String? helper, Widget? suffix}) {
  final p = context.pal;
  OutlineInputBorder b(Color c, [double w = 1]) =>
      OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: c, width: w));
  final edge = b(p.onHero.withValues(alpha: 0.18));
  return InputDecoration(
    labelText: label,
    helperText: helper,
    helperMaxLines: 2,
    suffixIcon: suffix,
    filled: true,
    fillColor: p.onHero.withValues(alpha: 0.06),
    labelStyle: TextStyle(color: p.heroMute),
    helperStyle: TextStyle(color: p.heroMute),
    errorStyle: TextStyle(color: Palette.dark.bad),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    border: edge,
    enabledBorder: edge,
    focusedBorder: b(p.sodium, 2),
    errorBorder: b(Palette.dark.bad),
    focusedErrorBorder: b(Palette.dark.bad, 2),
  );
}

/// Dark backdrop shared by sign-in, welcome, password reset and the floating app shell.
/// [lit] 1 = lamp on (warm glow), 0 = lights out.
class DarkScene extends StatelessWidget {
  final Widget child;
  final double lit;
  final Alignment glow;
  const DarkScene({super.key, required this.child, this.lit = 1, this.glow = const Alignment(-0.6, 0.5)});

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final off = Palette.dark.hero;
    return SizedBox.expand(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color.lerp(off, p.hero, lit)!, Color.lerp(off, Color.lerp(p.hero, p.ultraDeep, 0.5)!, lit)!],
          ),
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(center: glow, radius: 0.8, colors: [p.sodium.withValues(alpha: 0.2 * lit), p.sodium.withValues(alpha: 0)]),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Translucent card for dark scenes.
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  const GlassCard({super.key, required this.child, this.padding = const EdgeInsets.all(24)});

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: p.onHero.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: p.onHero.withValues(alpha: 0.14)),
        boxShadow: [BoxShadow(color: p.shadow, blurRadius: 40, offset: const Offset(0, 16))],
      ),
      child: child,
    );
  }
}