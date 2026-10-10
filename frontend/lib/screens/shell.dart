import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../state/providers.dart';
import '../theme.dart';
import '../widgets/common.dart';

class AppShell extends ConsumerWidget {
  final String location;
  final Widget child;
  const AppShell({super.key, required this.location, required this.child});

  int get _index => location.startsWith('/history') ? 1 : 0;

  void _go(BuildContext context, int i) => context.go(i == 1 ? '/history' : '/projects');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authServiceProvider);
    final wide = MediaQuery.of(context).size.width >= 900;

    if (wide) {
      return Scaffold(
        body: Row(children: [
          Container(
            width: 236,
            decoration: const BoxDecoration(color: Tk.gate, border: Border(right: BorderSide(color: Tk.line))),
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const Padding(padding: EdgeInsets.only(left: 8, bottom: 28), child: Wordmark()),
              _NavItem(icon: Icons.folder_outlined, label: 'Projects', selected: _index == 0, onTap: () => _go(context, 0)),
              _NavItem(icon: Icons.history, label: 'History', selected: _index == 1, onTap: () => _go(context, 1)),
              const Spacer(),
              if (auth.email != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Text(auth.email!, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Tk.mute, fontSize: 13)),
                ),
              TextButton.icon(
                onPressed: () => auth.signOut(),
                icon: const Icon(Icons.logout, size: 18),
                label: const Text('Sign out'),
                style: TextButton.styleFrom(alignment: Alignment.centerLeft, foregroundColor: Tk.mute),
              ),
            ]),
          ),
          Expanded(child: child),
        ]),
      );
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Tk.bleach,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        title: const Wordmark(size: 20),
        actions: [
          IconButton(tooltip: 'Sign out', icon: const Icon(Icons.logout), onPressed: () => auth.signOut()),
        ],
      ),
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => _go(context, i),
        destinations: const [
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
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Material(
          color: selected ? Tk.ultraSoft : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              child: Row(children: [
                Icon(icon, size: 20, color: selected ? Tk.ultra : Tk.mute),
                const SizedBox(width: 12),
                Text(label, style: TextStyle(fontWeight: FontWeight.w600, color: selected ? Tk.ultra : Tk.ink)),
              ]),
            ),
          ),
        ),
      );
}
