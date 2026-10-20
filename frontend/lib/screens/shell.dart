import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../state/providers.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/pip.dart';

const _pipTips = [
  'Open on the payoff, then explain.',
  'Most people watch with the sound off. Add text.',
  'Cut every pause longer than half a second.',
  'End on a reason to rewatch.',
  'One video, one idea.',
  'Try three hooks and keep the best score.',
  'Relatable beats polished.',
];

class AppShell extends ConsumerWidget {
  final String location;
  final Widget child;
  const AppShell({super.key, required this.location, required this.child});

  int get _index {
    if (location.startsWith('/dashboard')) return 0;
    if (location.startsWith('/history')) return 2;
    return 1;
  }

  void _go(BuildContext context, int i) => context.go(const ['/dashboard', '/projects', '/history'][i]);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.pal;
    final size = MediaQuery.of(context).size;
    final wide = size.width >= 900;

    if (wide) {
      return Scaffold(
        body: Row(children: [
          Container(
            width: 236,
            decoration: BoxDecoration(color: p.surface, border: Border(right: BorderSide(color: p.line))),
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const Padding(padding: EdgeInsets.only(left: 8, bottom: 28), child: Wordmark()),
              _NavItem(icon: Icons.space_dashboard_outlined, label: 'Dashboard', selected: _index == 0, onTap: () => _go(context, 0)),
              _NavItem(icon: Icons.folder_outlined, label: 'Projects', selected: _index == 1, onTap: () => _go(context, 1)),
              _NavItem(icon: Icons.history, label: 'History', selected: _index == 2, onTap: () => _go(context, 2)),
              const Spacer(),
              if (size.height >= 720) ...[
                const _PipTip(),
                const SizedBox(height: 12),
              ],
              const _AccountMenu(),
            ]),
          ),
          Expanded(child: child),
        ]),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Wordmark(size: 20),
        actions: const [Padding(padding: EdgeInsets.only(right: 12), child: _AccountMenu(compact: true))],
      ),
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => _go(context, i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.space_dashboard_outlined), selectedIcon: Icon(Icons.space_dashboard), label: 'Dashboard'),
          NavigationDestination(icon: Icon(Icons.folder_outlined), selectedIcon: Icon(Icons.folder), label: 'Projects'),
          NavigationDestination(icon: Icon(Icons.history), label: 'History'),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _NavItem({required this.icon, required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: selected ? p.ultraSoft : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(children: [
              Icon(icon, size: 20, color: selected ? p.ultra : p.mute),
              const SizedBox(width: 12),
              Text(label, style: TextStyle(fontWeight: FontWeight.w600, color: selected ? p.ultra : p.text)),
            ]),
          ),
        ),
      ),
    );
  }
}

class _PipTip extends StatelessWidget {
  const _PipTip();

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: p.surfaceAlt, borderRadius: BorderRadius.circular(12), border: Border.all(color: p.line)),
      child: Row(children: [
        const PipMark(size: 44),
        const SizedBox(width: 8),
        Expanded(child: Text(_pipTips[DateTime.now().weekday % _pipTips.length], style: context.ty.caption)),
      ]),
    );
  }
}

class _AccountMenu extends ConsumerWidget {
  final bool compact;
  const _AccountMenu({this.compact = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.pal;
    final auth = ref.watch(authServiceProvider);
    final mode = ref.watch(themeModeProvider);
    final email = auth.email ?? '';
    final initial = email.isEmpty ? '?' : email[0].toUpperCase();
    final avatar = CircleAvatar(
      radius: 16,
      backgroundColor: p.ultraSoft,
      child: Text(initial, style: TextStyle(color: p.ultra, fontWeight: FontWeight.w700)),
    );
    return PopupMenuButton<String>(
      key: const Key('account-menu'),
      tooltip: 'Account',
      onSelected: (v) {
        switch (v) {
          case 'light':
            ref.read(themeModeProvider.notifier).set(ThemeMode.light);
          case 'dark':
            ref.read(themeModeProvider.notifier).set(ThemeMode.dark);
          case 'system':
            ref.read(themeModeProvider.notifier).set(ThemeMode.system);
          case 'sign_out':
            auth.signOut();
        }
      },
      itemBuilder: (_) => [
        PopupMenuItem<String>(
          enabled: false,
          child: Text(email.isEmpty ? 'Signed in' : email, style: TextStyle(color: p.mute, fontSize: 13)),
        ),
        const PopupMenuDivider(),
        CheckedPopupMenuItem<String>(value: 'light', checked: mode == ThemeMode.light, child: const Text('Light')),
        CheckedPopupMenuItem<String>(value: 'dark', checked: mode == ThemeMode.dark, child: const Text('Dark')),
        CheckedPopupMenuItem<String>(value: 'system', checked: mode == ThemeMode.system, child: const Text('Match system')),
        const PopupMenuDivider(),
        const PopupMenuItem<String>(value: 'sign_out', child: Text('Sign out')),
      ],
      child: compact
          ? avatar
          : Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(border: Border.all(color: p.line), borderRadius: BorderRadius.circular(10)),
              child: Row(children: [
                avatar,
                const SizedBox(width: 10),
                Expanded(
                  child: Text(email.isEmpty ? 'Account' : email,
                      maxLines: 1, overflow: TextOverflow.ellipsis, style: context.ty.caption.copyWith(color: p.text)),
                ),
                Icon(Icons.unfold_more, size: 18, color: p.mute),
              ]),
            ),
    );
  }
}