import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../state/providers.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/dark_ui.dart';
import '../widgets/fx.dart';
import '../widgets/pip.dart';

const _tips = [
  'Open on the payoff, then explain.',
  'Most people watch with the sound off. Add text.',
  'Cut every pause longer than half a second.',
  'End on a reason to rewatch.',
  'One video, one idea.',
  'Try three hooks and keep the best score.',
  'Relatable beats polished.',
];

const _nav = <(String, String, IconData)>[
  ('Dashboard', '/dashboard', Icons.space_dashboard_outlined),
  ('Projects', '/projects', Icons.folder_outlined),
  ('History', '/history', Icons.history),
  ('Profile', '/profile', Icons.person_outline),
  ('Settings', '/settings', Icons.settings_outlined),
];

String _nameOf(String? email) {
  final raw = (email ?? '').split('@').first.replaceAll(RegExp(r'[^A-Za-z]'), ' ').trim();
  return raw.isEmpty ? 'Creator' : '${raw[0].toUpperCase()}${raw.substring(1).split(' ').first}';
}

class AppShell extends ConsumerWidget {
  final String location;
  final Widget child;
  const AppShell({super.key, required this.location, required this.child});

  int get _index {
    final i = _nav.indexWhere((n) => location.startsWith(n.$2));
    return i < 0 ? 1 : i;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.pal;
    final size = MediaQuery.of(context).size;

    if (size.width >= 900) {
      void open() => showDialog<void>(context: context, builder: (_) => const _Palette());
      return CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.keyK, control: true): open,
          const SingleActivator(LogicalKeyboardKey.keyK, meta: true): open,
        },
        child: Focus(
          autofocus: true,
          child: Scaffold(
            backgroundColor: p.hero,
            body: DarkScene(
              glow: const Alignment(0.9, -0.9),
              child: Padding(
                padding: EdgeInsets.all(size.width >= 1100 ? 28 : 16),
                child: Reveal(
                  dy: 16,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        ...p.lift,
                        BoxShadow(color: p.ultra.withValues(alpha: 0.3), blurRadius: 70, spreadRadius: -12, offset: const Offset(0, 30)),
                      ],
                    ),
                    child: Material(
                      color: p.bg,
                      clipBehavior: Clip.antiAlias,
                      borderRadius: BorderRadius.circular(28),
                      child: Row(children: [
                        _Sidebar(index: _index, showCard: size.height >= 720),
                        Expanded(child: Column(children: [_TopBar(onSearch: open), Expanded(child: child)])),
                      ]),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
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
        onDestinationSelected: (i) => context.go(_nav[i].$2),
        destinations: [for (final n in _nav) NavigationDestination(icon: Icon(n.$3), label: n.$1)],
      ),
    );
  }
}

class _Sidebar extends StatelessWidget {
  final int index;
  final bool showCard;
  const _Sidebar({required this.index, required this.showCard});

  @override
  Widget build(BuildContext context) => Container(
        width: 232,
        color: context.pal.surface,
        padding: const EdgeInsets.fromLTRB(14, 24, 14, 14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Padding(padding: EdgeInsets.only(left: 10, bottom: 22), child: Wordmark()),
          const _Label('MENU'),
          for (var i = 0; i < 3; i++) _NavItem(item: _nav[i], selected: index == i),
          const SizedBox(height: 14),
          const _Label('GENERAL'),
          for (var i = 3; i < _nav.length; i++) _NavItem(item: _nav[i], selected: index == i),
          const Spacer(),
          if (showCard) const _StudioCard(),
        ]),
      );
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
        child: Text(text, style: context.ty.caption.copyWith(fontSize: 11, letterSpacing: 1.2, fontWeight: FontWeight.w700)),
      );
}

class _NavItem extends StatelessWidget {
  final (String, String, IconData) item;
  final bool selected;
  const _NavItem({required this.item, required this.selected});

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: selected ? p.ultraSoft.withValues(alpha: 0.6) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          hoverColor: p.ultraSoft.withValues(alpha: 0.5),
          onTap: () => context.go(item.$2),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 11),
            child: Row(children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 3,
                height: 20,
                decoration: BoxDecoration(color: selected ? p.ultra : Colors.transparent, borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(width: 10),
              Icon(item.$3, size: 20, color: selected ? p.ultra : p.mute),
              const SizedBox(width: 10),
              Expanded(
                child: Text(item.$1,
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w600, color: selected ? p.ultra : p.text)),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

class _StudioCard extends StatelessWidget {
  const _StudioCard();

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: p.hero,
        borderRadius: BorderRadius.circular(kRadius),
        border: Border.all(color: p.onHero.withValues(alpha: 0.08)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          const PipMark(size: 40),
          const SizedBox(width: 8),
          Expanded(child: Text(_tips[DateTime.now().weekday % _tips.length], maxLines: 3, overflow: TextOverflow.ellipsis, style: context.ty.caption.copyWith(color: p.heroMute))),
        ]),
        const SizedBox(height: 10),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: p.sodium, foregroundColor: p.onSodium, minimumSize: const Size(44, 40)),
          onPressed: () => context.go('/dashboard'),
          child: const Text('Analyse a new video', textAlign: TextAlign.center),
        ),
      ]),
    );
  }
}

class _TopBar extends ConsumerWidget {
  final VoidCallback onSearch;
  const _TopBar({required this.onSearch});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 16, 28, 0),
      child: Row(children: [
        Expanded(
          child: Align(
            alignment: Alignment.centerLeft,
            child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 380), child: _SearchPill(onTap: onSearch)),
          ),
        ),
        const SizedBox(width: 12),
        IconButton.outlined(
          tooltip: 'Toggle theme',
          icon: Icon(dark ? Icons.light_mode_outlined : Icons.dark_mode_outlined),
          onPressed: () => ref.read(themeModeProvider.notifier).set(dark ? ThemeMode.light : ThemeMode.dark),
        ),
        const SizedBox(width: 12),
        const _AccountMenu(),
      ]),
    );
  }
}

class _SearchPill extends StatelessWidget {
  final VoidCallback onTap;
  const _SearchPill({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Semantics(
      button: true,
      label: 'Search',
      child: Material(
        color: p.surface,
        shape: StadiumBorder(side: BorderSide(color: p.line)),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(children: [
              Icon(Icons.search, size: 20, color: p.mute),
              const SizedBox(width: 8),
              Expanded(child: Text('Search reports and projects', maxLines: 1, overflow: TextOverflow.ellipsis, style: context.ty.caption.copyWith(fontSize: 14))),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: p.surfaceAlt, borderRadius: BorderRadius.circular(6), border: Border.all(color: p.line)),
                child: Text('⌘K', style: context.ty.caption.copyWith(fontSize: 12, fontWeight: FontWeight.w600)),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

class _AccountMenu extends ConsumerWidget {
  final bool compact;
  const _AccountMenu({this.compact = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.pal;
    final ty = context.ty;
    final auth = ref.watch(authServiceProvider);
    final email = auth.email ?? '';
    final saved = ref.watch(profileProvider).name;
    final name = saved.isEmpty ? _nameOf(email) : saved;
    final avatar = CircleAvatar(
      radius: 17,
      backgroundColor: p.ultraSoft,
      child: Text(name[0].toUpperCase(), style: TextStyle(color: p.ultra, fontWeight: FontWeight.w700)),
    );
    return PopupMenuButton<String>(
      key: const Key('account-menu'),
      tooltip: 'Account',
      onSelected: (v) => v == 'sign_out' ? auth.signOut() : context.go('/$v'),
      itemBuilder: (_) => [
        PopupMenuItem<String>(enabled: false, child: Text(email.isEmpty ? 'Signed in' : email, style: TextStyle(color: p.mute, fontSize: 13))),
        const PopupMenuDivider(),
        const PopupMenuItem<String>(value: 'profile', child: Text('Profile')),
        const PopupMenuItem<String>(value: 'settings', child: Text('Settings')),
        const PopupMenuDivider(),
        const PopupMenuItem<String>(value: 'sign_out', child: Text('Sign out')),
      ],
      child: compact
          ? avatar
          : Row(mainAxisSize: MainAxisSize.min, children: [
              avatar,
              const SizedBox(width: 10),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 170),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                  Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: ty.bodyStrong.copyWith(fontSize: 14)),
                  Text(email, maxLines: 1, overflow: TextOverflow.ellipsis, style: ty.caption.copyWith(fontSize: 12)),
                ]),
              ),
              Icon(Icons.expand_more, color: p.mute),
            ]),
    );
  }
}

/// Ctrl/⌘+K: jump to any page.
class _Palette extends StatefulWidget {
  const _Palette();

  @override
  State<_Palette> createState() => _PaletteState();
}

class _PaletteState extends State<_Palette> {
  final _q = TextEditingController();

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  void _go(String route) {
    final r = GoRouter.of(context);
    Navigator.pop(context);
    r.go(route);
  }

  @override
  Widget build(BuildContext context) {
    final q = _q.text.trim().toLowerCase();
    final items = _nav.where((n) => n.$1.toLowerCase().contains(q)).toList();
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
              controller: _q,
              autofocus: true,
              onChanged: (_) => setState(() {}),
              onSubmitted: items.isEmpty ? null : (_) => _go(items.first.$2),
              decoration: fieldDecoration(context, 'Jump to'),
            ),
            const SizedBox(height: 8),
            for (final n in items) ListTile(leading: Icon(n.$3), title: Text(n.$1), onTap: () => _go(n.$2)),
            if (items.isEmpty) Padding(padding: const EdgeInsets.all(16), child: Text('Nothing matches.', style: context.ty.caption)),
          ]),
        ),
      ),
    );
  }
}