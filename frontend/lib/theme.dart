import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

const kRadius = 14.0;
const kPink = Color(0xFFFF5DA2);
const kMint = Color(0xFF1FCFA0);

/// Motion switch. Turned off in tests (they build the theme with webFonts: false).
class Fx {
  static bool enabled = true;
}

bool _webFonts = true;

/// Every colour in the app lives here. Light and dark are two instances of the same set.
@immutable
class Palette extends ThemeExtension<Palette> {
  final Color bg;
  final Color surface;
  final Color surfaceAlt;
  final Color text;
  final Color mute;
  final Color line;
  final Color track;
  final Color ultra;
  final Color onUltra;
  final Color ultraSoft;
  final Color sodium;
  final Color onSodium;
  final Color good;
  final Color goodSoft;
  final Color warn;
  final Color warnSoft;
  final Color bad;
  final Color badSoft;
  final Color hero;
  final Color onHero;
  final Color heroMute;
  final Color heroTrack;
  final Color shadow;

  const Palette({
    required this.bg,
    required this.surface,
    required this.surfaceAlt,
    required this.text,
    required this.mute,
    required this.line,
    required this.track,
    required this.ultra,
    required this.onUltra,
    required this.ultraSoft,
    required this.sodium,
    required this.onSodium,
    required this.good,
    required this.goodSoft,
    required this.warn,
    required this.warnSoft,
    required this.bad,
    required this.badSoft,
    required this.hero,
    required this.onHero,
    required this.heroMute,
    required this.heroTrack,
    required this.shadow,
  });

  static const light = Palette(
    bg: Color(0xFFEDF0F5),
    surface: Color(0xFFFFFFFF),
    surfaceAlt: Color(0xFFF5F7FB),
    text: Color(0xFF121A33),
    mute: Color(0xFF566082),
    line: Color(0xFFD5DAE6),
    track: Color(0xFFDDE1EC),
    ultra: Color(0xFF3A36E8),
    onUltra: Color(0xFFFFFFFF),
    ultraSoft: Color(0xFFE6E5FC),
    sodium: Color(0xFFFFC83D),
    onSodium: Color(0xFF121A33),
    good: Color(0xFF0B7A55),
    goodSoft: Color(0xFFDDF3EA),
    warn: Color(0xFF8A5A00),
    warnSoft: Color(0xFFFFF0CC),
    bad: Color(0xFFB42318),
    badSoft: Color(0xFFFCE4E1),
    hero: Color(0xFF121A33),
    onHero: Color(0xFFFFFFFF),
    heroMute: Color(0xFFC3CAE0),
    heroTrack: Color(0xFF2A3560),
    shadow: Color(0x1A121A33),
  );

  static const dark = Palette(
    bg: Color(0xFF0B1022),
    surface: Color(0xFF141B33),
    surfaceAlt: Color(0xFF1A2342),
    text: Color(0xFFEEF1FA),
    mute: Color(0xFF9AA5C8),
    line: Color(0xFF2A3560),
    track: Color(0xFF263057),
    ultra: Color(0xFF9391FF),
    onUltra: Color(0xFF0B1022),
    ultraSoft: Color(0xFF252B66),
    sodium: Color(0xFFFFC83D),
    onSodium: Color(0xFF121A33),
    good: Color(0xFF3DDBA6),
    goodSoft: Color(0xFF12362D),
    warn: Color(0xFFF2BC62),
    warnSoft: Color(0xFF3A2C10),
    bad: Color(0xFFFF8F85),
    badSoft: Color(0xFF40191A),
    hero: Color(0xFF070B18),
    onHero: Color(0xFFFFFFFF),
    heroMute: Color(0xFFB7C0DE),
    heroTrack: Color(0xFF232C55),
    shadow: Color(0x59000000),
  );

  /// The one soft shadow level.
  List<BoxShadow> get lift => [BoxShadow(color: shadow, blurRadius: 24, offset: const Offset(0, 8))];

  @override
  Palette copyWith() => this;

  @override
  Palette lerp(ThemeExtension<Palette>? other, double t) => (t < 0.5 || other is! Palette) ? this : other;
}

/// Five roles: display (hero headlines), title (page titles), heading (card titles), body, caption.
/// `score` is the one oversized numeral.
class TypeScale {
  final Palette p;
  const TypeScale(this.p);

  TextStyle _brand(double size, FontWeight w, {double? height, double spacing = -0.4}) {
    final base = TextStyle(fontSize: size, fontWeight: w, color: p.text, height: height, letterSpacing: spacing);
    return _webFonts ? GoogleFonts.bricolageGrotesque(textStyle: base) : base;
  }

  TextStyle get score => _brand(88, FontWeight.w700, height: 0.95, spacing: -3);
  TextStyle get display => _brand(40, FontWeight.w700, height: 1.05, spacing: -1.2);
  TextStyle get title => _brand(28, FontWeight.w700, height: 1.1, spacing: -0.8);
  TextStyle get heading => _brand(18, FontWeight.w600, height: 1.2, spacing: -0.3);
  TextStyle get body => TextStyle(fontSize: 15, height: 1.5, color: p.text);
  TextStyle get bodyStrong => body.copyWith(fontWeight: FontWeight.w600);
  TextStyle get caption => TextStyle(fontSize: 13, height: 1.4, color: p.mute);
}

extension PaletteContext on BuildContext {
  Palette get pal => Theme.of(this).extension<Palette>() ?? Palette.light;
  TypeScale get ty => TypeScale(pal);
}

ThemeData buildTheme({bool webFonts = true, Brightness brightness = Brightness.light}) {
  _webFonts = webFonts;
  Fx.enabled = webFonts;
  final p = brightness == Brightness.dark ? Palette.dark : Palette.light;
  final scheme = ColorScheme(
    brightness: brightness,
    primary: p.ultra,
    onPrimary: p.onUltra,
    secondary: p.text,
    onSecondary: p.bg,
    error: p.bad,
    onError: p.onUltra,
    surface: p.surface,
    onSurface: p.text,
  );
  final base = ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: p.bg,
    extensions: [p],
  );
  final text = (webFonts ? GoogleFonts.instrumentSansTextTheme(base.textTheme) : base.textTheme)
      .apply(bodyColor: p.text, displayColor: p.text);
  final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(10));
  return base.copyWith(
    textTheme: text,
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: p.ultra,
        foregroundColor: p.onUltra,
        minimumSize: const Size(44, 46),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        shape: shape,
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: p.text,
        minimumSize: const Size(44, 46),
        padding: const EdgeInsets.symmetric(horizontal: 18),
        side: BorderSide(color: p.line),
        shape: shape,
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: p.ultra, textStyle: const TextStyle(fontWeight: FontWeight.w600)),
    ),
    dividerTheme: DividerThemeData(color: p.line, space: 1, thickness: 1),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: p.text,
      contentTextStyle: TextStyle(color: p.bg, fontSize: 14),
    ),
    popupMenuTheme: PopupMenuThemeData(color: p.surface, surfaceTintColor: Colors.transparent),
    appBarTheme: AppBarTheme(
      backgroundColor: p.bg,
      foregroundColor: p.text,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: p.surface,
      indicatorColor: p.ultraSoft,
      surfaceTintColor: Colors.transparent,
    ),
    chipTheme: ChipThemeData(
      backgroundColor: p.surface,
      selectedColor: p.ultraSoft,
      side: BorderSide(color: p.line),
      labelStyle: TextStyle(color: p.text),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: p.ultra, linearTrackColor: p.track),
    visualDensity: VisualDensity.standard,
  );
}

InputDecoration fieldDecoration(BuildContext context, String label, {String? hint, String? helper, Widget? suffix}) {
  final p = context.pal;
  OutlineInputBorder border(Color c, [double w = 1]) =>
      OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: c, width: w));
  return InputDecoration(
    labelText: label,
    hintText: hint,
    helperText: helper,
    helperMaxLines: 3,
    suffixIcon: suffix,
    filled: true,
    fillColor: p.surface,
    labelStyle: TextStyle(color: p.mute),
    hintStyle: TextStyle(color: p.mute.withValues(alpha: 0.8)),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    border: border(p.line),
    enabledBorder: border(p.line),
    focusedBorder: border(p.ultra, 2),
    errorBorder: border(p.bad),
    focusedErrorBorder: border(p.bad, 2),
  );
}