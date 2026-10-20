import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../api/auth_service.dart';
import '../state/providers.dart';
import '../theme.dart';
import '../util/format.dart';
import '../util/profile.dart';
import '../widgets/charts.dart';
import '../widgets/common.dart';
import '../widgets/fx.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  late final Profile _p = ref.read(profileProvider);
  late final _name = TextEditingController(text: _p.name);
  late final _niche = TextEditingController(text: _p.niche);
  late final _aud = TextEditingController(text: _p.audience);
  final _pw = TextEditingController();
  final _pwForm = GlobalKey<FormState>();
  late String _platform = _p.platform;
  late String _goal = _p.goal;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _niche.dispose();
    _aud.dispose();
    _pw.dispose();
    super.dispose();
  }

  void _save() {
    ref.read(profileProvider.notifier).set(Profile(
          name: _name.text.trim(),
          platform: _platform,
          niche: _niche.text.trim(),
          audience: _aud.text.trim(),
          goal: _goal,
        ));
    toast(context, 'Profile saved.');
  }

  Future<void> _password() async {
    if (_busy || !_pwForm.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await ref.read(authServiceProvider).updatePassword(_pw.text);
      _pw.clear();
      if (mounted) toast(context, 'Password updated.');
    } on AuthFailure catch (e) {
      if (mounted) toast(context, e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _chips(List<(String, String)> items, String current, ValueChanged<String> pick) => Wrap(spacing: 8, runSpacing: 8, children: [
        for (final o in items) ChoiceChip(label: Text(o.$1), selected: current == o.$2, onSelected: (_) => setState(() => pick(o.$2))),
      ]);

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final ty = context.ty;
    final email = ref.watch(authServiceProvider).email ?? '';
    final shown = _name.text.trim().isEmpty ? email : _name.text.trim();
    return PageFrame(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const PageHeader(title: 'Profile', subtitle: 'What Pip knows about you. It stays in this browser.'),
        Reveal(
          child: SectionCard(
            title: 'About you',
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: p.ultraSoft,
                  child: Text(shown.isEmpty ? '?' : shown[0].toUpperCase(), style: TextStyle(color: p.ultra, fontSize: 22, fontWeight: FontWeight.w700)),
                ),
                const SizedBox(width: 14),
                Expanded(child: Text(email.isEmpty ? 'Signed in' : email, maxLines: 1, overflow: TextOverflow.ellipsis, style: ty.bodyStrong)),
              ]),
              const SizedBox(height: 16),
              TextFormField(controller: _name, maxLength: 40, onChanged: (_) => setState(() {}), decoration: fieldDecoration(context, 'Your name')),
            ]),
          ),
        ),
        const SizedBox(height: 16),
        Reveal(
          delayMs: 60,
          child: SectionCard(
            title: 'Your content',
            subtitle: 'Quick Studio uses this so you never retype it.',
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Where you post', style: ty.bodyStrong),
              const SizedBox(height: 8),
              _chips([for (final e in platformLabels.entries) (e.value, e.key)], _platform, (v) => _platform = v),
              const SizedBox(height: 16),
              TextFormField(controller: _niche, maxLength: 100, decoration: fieldDecoration(context, 'Niche', hint: 'Budget cooking')),
              const SizedBox(height: 6),
              TextFormField(controller: _aud, maxLength: 200, decoration: fieldDecoration(context, 'Target audience', hint: 'College students')),
              const SizedBox(height: 10),
              Text('What you want most', style: ty.bodyStrong),
              const SizedBox(height: 8),
              _chips([for (final g in kGoals) (g, g)], _goal, (v) => _goal = _goal == v ? '' : v),
              const SizedBox(height: 20),
              FilledButton(onPressed: _save, child: const Text('Save changes')),
            ]),
          ),
        ),
        const SizedBox(height: 16),
        Reveal(
          delayMs: 120,
          child: SectionCard(
            title: 'Password',
            child: Form(
              key: _pwForm,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                TextFormField(
                  controller: _pw,
                  obscureText: true,
                  decoration: fieldDecoration(context, 'New password', helper: 'At least 8 characters.'),
                  validator: (v) => (v == null || v.length < 8) ? 'Use at least 8 characters.' : null,
                ),
                const SizedBox(height: 12),
                OutlinedButton(onPressed: _busy ? null : _password, child: const Text('Update password')),
              ]),
            ),
          ),
        ),
        const SizedBox(height: 16),
        OutlinedButton(onPressed: () => context.go('/welcome'), child: const Text('Redo the welcome questions')),
      ]),
    );
  }
}