import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../state/providers.dart';
import '../theme.dart';
import '../util/format.dart';
import '../util/profile.dart';
import '../widgets/common.dart';
import '../widgets/dark_ui.dart';
import '../widgets/frame_strip.dart';
import '../widgets/login_scene.dart';

const _titles = [
  'What should Pip call you?',
  'What do you make?',
  'Where do you post?',
  'Who is it for?',
  'What do you want most?',
];

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  late final Profile _start = ref.read(profileProvider);
  late final _name = TextEditingController(text: _start.name);
  late final _niche = TextEditingController(text: _start.niche);
  late final _aud = TextEditingController(text: _start.audience);
  late String _platform = '';
  late String _goal = _start.goal;
  int _i = 0;

  @override
  void dispose() {
    _name.dispose();
    _niche.dispose();
    _aud.dispose();
    super.dispose();
  }

  void _finish() {
    String? keep(String v) => v.trim().isEmpty ? null : v.trim();
    ref.read(profileProvider.notifier).set(ref.read(profileProvider).copyWith(
          name: keep(_name.text),
          niche: keep(_niche.text),
          audience: keep(_aud.text),
          platform: keep(_platform),
          goal: keep(_goal),
        ));
    markOnboarded(ref.read(authServiceProvider).email);
    context.go('/dashboard');
  }

  void _next() => _i == _titles.length - 1 ? _finish() : setState(() => _i++);

  void _skip() {
    switch (_i) {
      case 0:
        _name.clear();
      case 1:
        _niche.clear();
      case 2:
        _platform = '';
      case 3:
        _aud.clear();
      default:
        _goal = '';
    }
    _next();
  }

  Widget _chips(List<(String, String)> items, String current, ValueChanged<String> pick) => Wrap(spacing: 8, runSpacing: 8, children: [
        for (final o in items) ChoiceChip(label: Text(o.$1), selected: current == o.$2, onSelected: (_) => pick(o.$2)),
      ]);

  Widget _text(TextEditingController c, String label, {bool autofocus = false}) => TextField(
        controller: c,
        autofocus: autofocus,
        style: TextStyle(color: context.pal.onHero),
        onChanged: (_) => setState(() {}),
        onSubmitted: (_) => _next(),
        decoration: darkField(context, label),
      );

  Widget _body() {
    List<(String, String)> same(List<String> l) => [for (final s in l) (s, s)];
    switch (_i) {
      case 0:
        return _text(_name, 'Your name', autofocus: true);
      case 1:
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _chips(same(kNiches), _niche.text, (v) => setState(() => _niche.text = v)),
          const SizedBox(height: 14),
          _text(_niche, 'Or type your own'),
        ]);
      case 2:
        return _chips([for (final e in platformLabels.entries) (e.value, e.key)], _platform, (v) => setState(() => _platform = v));
      case 3:
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _chips(same(kAudiences), _aud.text, (v) => setState(() => _aud.text = v)),
          const SizedBox(height: 14),
          _text(_aud, 'Or describe them'),
        ]);
      default:
        return _chips(same(kGoals), _goal, (v) => setState(() => _goal = v));
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final ty = context.ty;
    final last = _i == _titles.length - 1;
    return Scaffold(
      backgroundColor: Palette.dark.hero,
      body: DarkScene(
        glow: const Alignment(0, -0.2),
        child: SafeArea(
          child: Stack(children: [
            Positioned(
              top: 12,
              right: 16,
              child: TextButton(
                style: TextButton.styleFrom(foregroundColor: p.heroMute),
                onPressed: _finish,
                child: const Text('Skip all'),
              ),
            ),
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Wordmark(color: p.onHero, size: 24),
                    const SizedBox(height: 20),
                    Stack(alignment: Alignment.topCenter, children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 92),
                        child: GlassCard(
                          padding: const EdgeInsets.fromLTRB(24, 52, 24, 20),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                            FrameStrip(
                              value: (_i + 1) * 20.0,
                              cells: 5,
                              height: 10,
                              trackColor: p.onHero.withValues(alpha: 0.15),
                              fillColor: p.onHero,
                              semanticLabel: 'Step ${_i + 1} of ${_titles.length}',
                            ),
                            const SizedBox(height: 6),
                            Text('Step ${_i + 1} of ${_titles.length}. Every question is optional.', style: ty.caption.copyWith(color: p.heroMute)),
                            const SizedBox(height: 16),
                            Text(_titles[_i], style: ty.title.copyWith(color: p.onHero)),
                            const SizedBox(height: 16),
                            _body(),
                            const SizedBox(height: 24),
                            Wrap(alignment: WrapAlignment.spaceBetween, crossAxisAlignment: WrapCrossAlignment.center, runSpacing: 8, children: [
                              Row(mainAxisSize: MainAxisSize.min, children: [
                                TextButton(
                                  style: TextButton.styleFrom(foregroundColor: p.heroMute),
                                  onPressed: _skip,
                                  child: const Text('Skip'),
                                ),
                                if (_i > 0)
                                  TextButton(
                                    style: TextButton.styleFrom(foregroundColor: p.heroMute),
                                    onPressed: () => setState(() => _i--),
                                    child: const Text('Back'),
                                  ),
                              ]),
                              FilledButton(
                                style: FilledButton.styleFrom(backgroundColor: p.sodium, foregroundColor: p.onSodium),
                                onPressed: _next,
                                child: Text(last ? 'Finish' : 'Next'),
                              ),
                            ]),
                          ]),
                        ),
                      ),
                      LoginPip(size: 132, look: Offset(0, _i.isEven ? 0.6 : 0.3)),
                    ]),
                  ]),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}