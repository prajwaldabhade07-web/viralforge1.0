import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models.dart';
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

const _help = ('Help', '/help', Icons.help_outline);
const _all = [..._nav, _help];

String _nameOf(String? email) {
  final raw = (email ?? '').split('@').first.replaceAll(RegExp(r'[^A-Za-z]'), ' ').trim();
  return raw.isEmpty ? 'Creator' : '${raw[0].toUpperCase()}${raw.substring(1).split(' ').first}';
}

class AppShell extends ConsumerWidget {
  final String location;
  final Widget child;
  const AppShell({super.key, required this.location, required this.child});

  int get _index {
    if (location.startsWith('/new')) return 0;
    final i = _all.indexWhere((n) => location.startsWith(n.$2));
    return i < 0 ? 1 : i;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.pal;
    final size = MediaQuery.of(context).size;
    final running = ref.watch(activeJobsProvider).valueOrNull?.length ?? 0;

    // Tell the user when an analysis finishes while they are somewhere else.
    ref.listen<AsyncValue<List<Job>>>(activeJobsProvider, (prev, next) {
      final before = prev?.valueOrNull;
      final now = next.valueOrNull;
      if (before == null || now == null) return;
      final ids = now.map((j) => j.id).toSet();
      for (final j in before.where((j) => !ids.contains(j.id))) {
        if (location == '/analyses/${j.id}') continue;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Your analysis for ${j.projectName ?? j.niche} has finished.'),
          action: SnackBarAction(label: 'View', onPressed: () => context.go('/analyses/${j.id}')),
        ));
      }
    });

    final poller = LivePoller(active: Fx.enabled, every: const Duration(seconds: 6), onTick: () => ref.invalidate(activeJobsProvider));

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
                        _Sidebar(index: _index, showCard: size.height >= 720, running: running),
                        Expanded(child: Column(children: [poller, _TopBar(onSearch: open), Expanded(child: child)])),
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
        actions: const [
          _Tracker(compact: true),
          SizedBox(width: 8),
          Padding(padding: EdgeInsets.only(right: 12), child: _AccountMenu(compact: true)),
        ],
      ),
      body: Column(children: [poller, Expanded(child: child)]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index.clamp(0, _nav.length - 1).toInt(),
        onDestinationSelected: (i) => context.go(_nav[i].$2),
        destinations: [
          for (var i = 0; i < _nav.length; i++)
            NavigationDestination(
              icon: Badge(isLabelVisible: i == 2 && running > 0, label: Text('$running'), child: Icon(_nav[i].$3)),
              label: _nav[i].$1,
            ),
        ],
      ),
    );
  }
}

class _Sidebar extends StatelessWidget {
  final int index;
  final bool showCard;
  final int running;
  const _Sidebar({required this.index, required this.showCard, required this.running});

  @override
  Widget build(BuildContext context) => Container(
        width: 232,
        color: context.pal.surface,
        padding: const EdgeInsets.fromLTRB(14, 24, 14, 14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Padding(padding: EdgeInsets.only(left: 10, bottom: 22), child: Wordmark()),
          const _Label('MENU'),
          for (var i = 0; i < 3; i++) _NavItem(item: _nav[i], selected: index == i, badge: i == 2 ? running : 0),
          const SizedBox(height: 14),
          const _Label('GENERAL'),
          for (var i = 3; i < _all.length; i++) _NavItem(item: _all[i], selected: index == i),
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
  final int badge;
  const _NavItem({required this.item, required this.selected, this.badge = 0});

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
              if (badge > 0) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: p.ultra, borderRadius: BorderRadius.circular(10)),
                  child: Text('$badge', style: TextStyle(color: p.onUltra, fontSize: 11.5, fontWeight: FontWeight.w700)),
                ),
                const SizedBox(width: 10),
              ],
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
          const PipMark(size: 44),
          const SizedBox(width: 8),
          Expanded(child: Text(_tips[DateTime.now().weekday % _tips.length], maxLines: 3, overflow: TextOverflow.ellipsis, style: context.ty.caption.copyWith(color: p.heroMute))),
        ]),
        const SizedBox(height: 10),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: p.sodium, foregroundColor: p.onSodium, minimumSize: const Size(44, 40)),
          onPressed: () => context.go('/new'),
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
        const _Tracker(),
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

/// Shows while an analysis is queued or running, wherever you are in the app.
/// One analysis: tap to open it. Several: tap for a short list.
class _Tracker extends ConsumerWidget {
  final bool compact;
  const _Tracker({this.compact = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final jobs = ref.watch(activeJobsProvider).valueOrNull ?? const <Job>[];
    if (jobs.isEmpty) return const SizedBox.shrink();
    final p = context.pal;
    final label = jobs.length == 1 ? 'Analysing 1 video' : 'Analysing ${jobs.length} videos';
    final ring = SizedBox(
      width: 16,
      height: 16,
      child: CircularProgressIndicator(strokeWidth: 2.5, value: jobs.first.progress.clamp(0, 100) / 100),
    );
    final body = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: compact
          ? ring
          : Row(mainAxisSize: MainAxisSize.min, children: [
              ring,
              const SizedBox(width: 8),
              Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: p.ultra, fontWeight: FontWeight.w600, fontSize: 13))),
            ]),
    );
    final Widget action = jobs.length == 1
        ? Tooltip(
            message: 'See where your analysis is',
            child: InkWell(customBorder: const StadiumBorder(), onTap: () => context.go('/analyses/${jobs.first.id}'), child: body),
          )
        : PopupMenuButton<String>(
            tooltip: 'See where your analyses are',
            onSelected: (v) => v == '_all' ? context.go('/history') : context.go('/analyses/$v'),
            itemBuilder: (_) => [
              for (final j in jobs)
                PopupMenuItem<String>(
                  value: j.id,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 260),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                      Text(j.projectName ?? j.niche, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
                      Text('${moodCaption(moodForStage(j.status, j.stage))} ${j.progress}%', maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: p.mute, fontSize: 12.5)),
                    ]),
                  ),
                ),
              const PopupMenuDivider(),
              const PopupMenuItem<String>(value: '_all', child: Text('See all reports')),
            ],
            child: body,
          );
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 230),
        child: Material(color: p.ultraSoft, shape: const StadiumBorder(), child: action),
      ),
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
        const PopupMenuItem<String>(value: 'help', child: Text('Help')),
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
    final items = _all.where((n) => n.$1.toLowerCase().contains(q)).toList();
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