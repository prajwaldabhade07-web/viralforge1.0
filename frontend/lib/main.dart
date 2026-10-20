import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!AppConfig.isComplete) {
    runApp(const ConfigErrorApp());
    return;
  }
  try {
    // Load the brand fonts before the first frame so text never flashes in a fallback face.
    await GoogleFonts.pendingFonts([
      GoogleFonts.bricolageGrotesque(fontWeight: FontWeight.w600),
      GoogleFonts.bricolageGrotesque(fontWeight: FontWeight.w700),
      GoogleFonts.instrumentSans(),
      GoogleFonts.instrumentSans(fontWeight: FontWeight.w600),
      GoogleFonts.instrumentSans(fontWeight: FontWeight.w700),
    ]).timeout(const Duration(seconds: 4));
  } catch (_) {
    // Offline or slow: the app still starts and falls back for a moment.
  }
  await Supabase.initialize(url: AppConfig.supabaseUrl, anonKey: AppConfig.supabaseAnonKey);
  runApp(const ProviderScope(child: ViralForgeApp()));
}