import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'router.dart';
import 'theme.dart';

class ViralForgeApp extends ConsumerWidget {
  final bool webFonts;
  const ViralForgeApp({super.key, this.webFonts = true});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'ViralForge',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(webFonts: webFonts),
      routerConfig: ref.watch(routerProvider),
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
