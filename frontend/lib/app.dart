import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'router.dart';
import 'state/providers.dart';
import 'state/text_scale.dart';
import 'theme.dart';

class ViralForgeApp extends ConsumerWidget {
  final bool webFonts;
  const ViralForgeApp({super.key, this.webFonts = true});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accent = kAccents[ref.watch(accentProvider)].$2;
    final scale = ref.watch(textScaleProvider);
    return MaterialApp.router(
      title: 'ViralForge',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(webFonts: webFonts, accent: accent),
      darkTheme: buildTheme(webFonts: webFonts, brightness: Brightness.dark, accent: accent),
      themeMode: ref.watch(themeModeProvider),
      routerConfig: ref.watch(routerProvider),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
        child: child ?? const SizedBox.shrink(),
      ),
    );
  }
}

/// Shown instead of the app when the build was started without Supabase configuration.
class ConfigErrorApp extends StatelessWidget {
  const ConfigErrorApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildTheme(webFonts: false),
        home: const Scaffold(
          body: Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: SizedBox(
                width: 520,
                child: Text(
                  'ViralForge is not configured.\n\nStart the app with scripts\\run-frontend.ps1 so it can read your .env file '
                  '(it creates frontend\\config.json for you).',
                  style: TextStyle(fontSize: 16, height: 1.5),
                ),
              ),
            ),
          ),
        ),
      );
}