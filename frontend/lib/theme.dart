import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Design tokens. The product's one signature element is the film-strip score meter:
/// ultramarine frames with a single sodium-yellow "playhead" frame at the current score.
class Tk {
  static const bleach = Color(0xFFEDF0F5); // page background
  static const gate = Color(0xFFFFFFFF); // surfaces
  static const ink = Color(0xFF121A33); // text, dark surfaces
  static const ultra = Color(0xFF3A36E8); // primary
  static const ultraSoft = Color(0xFFE6E5FC);
  static const sodium = Color(0xFFFFC83D); // playhead only
  static const mute = Color(0xFF566082); // secondary text
  static const line = Color(0xFFD5DAE6);
  static const track = Color(0xFFDDE1EC);
  static const good = Color(0xFF0B7A55);
  static const goodSoft = Color(0xFFDDF3EA);
  static const warn = Color(0xFF8A5A00);
  static const warnSoft = Color(0xFFFFF0CC);
  static const bad = Color(0xFFB42318);
  static const badSoft = Color(0xFFFCE4E1);
  static const radius = 14.0;
}

bool _webFonts = true;

/// Display face: Bricolage Grotesque (falls back to the platform font when web fonts are off, e.g. in tests).
TextStyle display(double size, {FontWeight weight = FontWeight.w700, Color color = Tk.ink, double? height, double spacing = -0.4}) {
  final base = TextStyle(fontSize: size, fontWeight: weight, color: color, height: height, letterSpacing: spacing);
  return _webFonts ? GoogleFonts.bricolageGrotesque(textStyle: base) : base;
}

ThemeData buildTheme({bool webFonts = true}) {
  _webFonts = webFonts;
  const scheme = ColorScheme(
    brightness: Brightness.light,
    primary: Tk.ultra,
    onPrimary: Colors.white,
    secondary: Tk.ink,
    onSecondary: Colors.white,
    error: Tk.bad,
    onError: Colors.white,
    surface: Tk.gate,
    onSurface: Tk.ink,
  );
  final base = ThemeData(useMaterial3: true, colorScheme: scheme, scaffoldBackgroundColor: Tk.bleach);
  final text = (webFonts ? GoogleFonts.instrumentSansTextTheme(base.textTheme) : base.textTheme)
      .apply(bodyColor: Tk.ink, displayColor: Tk.ink);
  final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(10));
  return base.copyWith(
    textTheme: text,
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: Tk.ultra,
        foregroundColor: Colors.white,
        minimumSize: const Size(44, 46),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        shape: shape,
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: Tk.ink,
        minimumSize: const Size(44, 46),
        padding: const EdgeInsets.symmetric(horizontal: 18),
        side: const BorderSide(color: Tk.line),
        shape: shape,
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: Tk.ultra, textStyle: const TextStyle(fontWeight: FontWeight.w600)),
    ),
    dividerTheme: const DividerThemeData(color: Tk.line, space: 1, thickness: 1),
    snackBarTheme: const SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: Tk.ink,
      contentTextStyle: TextStyle(color: Colors.white, fontSize: 14),
    ),
    visualDensity: VisualDensity.standard,
  );
}

/// Shared input styling (applied per field to stay independent of Flutter's theme-class renames).
InputDecoration fieldDecoration(String label, {String? hint, String? helper, Widget? suffix}) {
  OutlineInputBorder border(Color c, [double w = 1]) =>
      OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: c, width: w));
  return InputDecoration(
    labelText: label,
    hintText: hint,
    helperText: helper,
    helperMaxLines: 3,
    suffixIcon: suffix,
    filled: true,
    fillColor: Tk.gate,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    border: border(Tk.line),
    enabledBorder: border(Tk.line),
    focusedBorder: border(Tk.ultra, 2),
    errorBorder: border(Tk.bad),
    focusedErrorBorder: border(Tk.bad, 2),
  );
}
