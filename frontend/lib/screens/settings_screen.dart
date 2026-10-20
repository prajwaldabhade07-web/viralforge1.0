import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../state/providers.dart';
import '../theme.dart';
import '../widgets/charts.dart';
import '../widgets/common.dart';
import '../widgets/fx.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ty = context.ty;
    final accent = ref.watch(accentProvider);
    final auth = ref.watch(authServiceProvider);
    return PageFrame(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const PageHeader(title: 'Settings', subtitle: 'Make the cutting room yours.'),
        Reveal(
          child: SectionCard(
            title: 'Accent colour',
            subtitle: 'Dark mode lives in the moon button at the top.',
            child: Wrap(spacing: 12, runSpacing: 12, children: [
              for (var i = 0; i < kAccents.length; i++)
                _Swatch(name: kAccents[i].$1, color: kAccents[i].$2, selected: i == accent, onTap: () => ref.read(accentProvider.notifier).set(i)),
            ]),
          ),
        ),
        const SizedBox(height: 16),
        Reveal(
          delayMs: 60,
          child: SectionCard(
            title: 'Account',
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(auth.email ?? 'Signed in', style: ty.body),
              const SizedBox(height: 12),
              Wrap(spacing: 10, runSpacing: 10, children: [
                FilledButton(onPressed: () => context.go('/profile'), child: const Text('Edit profile')),
                OutlinedButton(onPressed: auth.signOut, child: const Text('Sign out')),
              ]),
            ]),
          ),
        ),
      ]),
    );
  }
}

class _Swatch extends StatelessWidget {
  final String name;
  final Color color;
  final bool selected;
  final VoidCallback onTap;
  const _Swatch({required this.name, required this.color, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Tooltip(
      message: name,
      child: Semantics(
        button: true,
        selected: selected,
        label: '$name accent',
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color, border: selected ? Border.all(color: p.text, width: 3) : null),
            child: selected ? Icon(Icons.check, color: p.onHero, size: 20) : null,
          ),
        ),
      ),
    );
  }
}