import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../api/auth_service.dart';
import '../state/providers.dart';
import '../theme.dart';
import '../util/platform.dart';
import '../widgets/common.dart';
import '../widgets/dark_ui.dart';
import '../widgets/login_scene.dart';

final _emailRe = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController(text: readPref('vf_remember_email') ?? '');
  final _password = TextEditingController();
  final _emailFocus = FocusNode();
  final _passFocus = FocusNode();
  final _pipKey = GlobalKey();
  final _look = ValueNotifier<Offset>(Offset.zero);
  late bool _remember = (readPref('vf_remember_email') ?? '').isNotEmpty;
  bool _register = false;
  bool _busy = false;
  bool _obscure = true;
  bool _lit = true;
  String? _error;
  String? _info;

  @override
  void initState() {
    super.initState();
    _emailFocus.addListener(_refresh);
    _passFocus.addListener(_refresh);
    _email.addListener(() {
      if (_emailFocus.hasFocus) _refresh();
    });
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _emailFocus.dispose();
    _passFocus.dispose();
    _look.dispose();
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  void _track(Offset global) {
    final box = _pipKey.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.attached) return;
    final d = global - box.localToGlobal(box.size.center(Offset.zero));
    _look.value = Offset((d.dx / 300).clamp(-1.0, 1.0).toDouble(), (d.dy / 300).clamp(-1.0, 1.0).toDouble());
  }

  Future<void> _submit() async {
    if (_busy || !_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
      _info = null;
    });
    ref.read(sessionNoticeProvider.notifier).state = null;
    final auth = ref.read(authServiceProvider);
    final email = _email.text.trim();
    writePref('vf_remember_email', _remember ? email : '');
    try {
      if (_register) {
        final needsConfirm = await auth.register(email, _password.text);
        if (needsConfirm && mounted) {
          setState(() {
            _register = false;
            _info = 'Account created. Check your inbox to confirm your email, then sign in.';
          });
        }
      } else {
        await auth.signIn(email, _password.text);
      }
    } on AuthFailure catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _pip() {
    final typed = Offset((math.min(_email.text.length, 24) / 24) * 1.8 - 0.9, 0.8);
    return KeyedSubtree(
      key: _pipKey,
      child: ValueListenableBuilder<Offset>(
        valueListenable: _look,
        builder: (context, pointer, _) => LoginPip(
          size: 132,
          look: _emailFocus.hasFocus ? typed : pointer,
          cover: _passFocus.hasFocus ? 1 : 0,
          peek: _obscure ? 0 : 1,
        ),
      ),
    );
  }

  Widget _formBody() {
    final p = context.pal;
    final ty = context.ty;
    final notice = ref.watch(sessionNoticeProvider);
    final field = TextStyle(color: p.onHero);
    return Form(
      key: _form,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(_register ? 'Create your account' : 'Sign in', textAlign: TextAlign.center, style: ty.title.copyWith(color: p.onHero)),
        const SizedBox(height: 6),
        Text(_register ? 'Free to start. Use any email you can access.' : 'Welcome back. Pip is keeping watch.',
            textAlign: TextAlign.center, style: ty.body.copyWith(color: p.heroMute, fontSize: 14)),
        const SizedBox(height: 20),
        if (notice != null) ...[InlineMessage(MsgKind.info, notice), const SizedBox(height: 14)],
        if (_info != null) ...[InlineMessage(MsgKind.success, _info!), const SizedBox(height: 14)],
        if (_error != null) ...[InlineMessage(MsgKind.error, _error!), const SizedBox(height: 14)],
        TextFormField(
          controller: _email,
          focusNode: _emailFocus,
          style: field,
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.email],
          textInputAction: TextInputAction.next,
          decoration: darkField(context, 'Email'),
          validator: (v) => (v == null || !_emailRe.hasMatch(v.trim())) ? 'Enter a valid email address.' : null,
        ),
        const SizedBox(height: 14),
        TextFormField(
          controller: _password,
          focusNode: _passFocus,
          style: field,
          obscureText: _obscure,
          autofillHints: [_register ? AutofillHints.newPassword : AutofillHints.password],
          textInputAction: TextInputAction.done,
          onFieldSubmitted: (_) => _submit(),
          decoration: darkField(
            context,
            'Password',
            helper: _register ? 'At least 8 characters.' : null,
            suffix: IconButton(
              tooltip: _obscure ? 'Show password' : 'Hide password',
              icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined, color: p.heroMute),
              onPressed: () => setState(() => _obscure = !_obscure),
            ),
          ),
          validator: (v) {
            if (v == null || v.isEmpty) return 'Enter your password.';
            if (_register && v.length < 8) return 'Use at least 8 characters.';
            return null;
          },
        ),
        const SizedBox(height: 8),
        if (!_register)
          Wrap(alignment: WrapAlignment.spaceBetween, crossAxisAlignment: WrapCrossAlignment.center, children: [
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => setState(() => _remember = !_remember),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Checkbox(
                  value: _remember,
                  onChanged: (v) => setState(() => _remember = v ?? false),
                  side: BorderSide(color: p.heroMute),
                  activeColor: p.sodium,
                  checkColor: p.onSodium,
                ),
                Text('Remember me', style: ty.caption.copyWith(color: p.heroMute)),
              ]),
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: p.sodium),
              onPressed: _busy ? null : () => context.go('/forgot-password'),
              child: const Text('Forgot password?'),
            ),
          ]),
        const SizedBox(height: 10),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: p.sodium, foregroundColor: p.onSodium),
          onPressed: _busy ? null : _submit,
          child: _busy
              ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5, color: p.onSodium))
              : Text(_register ? 'Create account' : 'Sign in'),
        ),
        const SizedBox(height: 8),
        Wrap(alignment: WrapAlignment.center, crossAxisAlignment: WrapCrossAlignment.center, children: [
          if (!_register) Text('New to ViralForge?', style: ty.caption.copyWith(color: p.heroMute)),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: p.sodium),
            onPressed: _busy
                ? null
                : () => setState(() {
                      _register = !_register;
                      _error = null;
                      _info = null;
                    }),
            child: Text(_register ? 'I already have an account' : 'Create an account'),
          ),
        ]),
      ]),
    );
  }

  Widget _pipCard(double t) => Stack(alignment: Alignment.topCenter, children: [
        Padding(
          padding: const EdgeInsets.only(top: 92),
          child: Opacity(opacity: 0.6 + 0.4 * t, child: GlassCard(padding: const EdgeInsets.fromLTRB(24, 50, 24, 14), child: _formBody())),
        ),
        _pip(),
      ]);

  Widget _lamp() => SizedBox(width: 180, child: Lamp(lit: _lit, onToggle: () => setState(() => _lit = !_lit)));

  Widget _wide(double t) {
    final p = context.pal;
    final ty = context.ty;
    return Row(children: [
      Expanded(
        flex: 5,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(56, 40, 24, 32),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Wordmark(color: p.onHero, size: 24),
            const SizedBox(height: 32),
            Text('Know how your video will land before you post it.', style: ty.display.copyWith(fontSize: 46, color: p.onHero)),
            const SizedBox(height: 16),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Text('Upload a short clip. Get five scores, specific fixes, and ten simulated viewer reactions.',
                  style: ty.body.copyWith(color: p.heroMute, fontSize: 16)),
            ),
            Expanded(child: Align(alignment: Alignment.bottomLeft, child: FittedBox(fit: BoxFit.scaleDown, child: _lamp()))),
          ]),
        ),
      ),
      Expanded(
        flex: 4,
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 420), child: _pipCard(t)),
          ),
        ),
      ),
    ]);
  }

  Widget _narrow(double t) {
    final p = context.pal;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wordmark(color: p.onHero, size: 22),
        const SizedBox(height: 14),
        Text('Know how your video will land before you post it.', style: context.ty.display.copyWith(fontSize: 28, color: p.onHero)),
        const SizedBox(height: 18),
        _pipCard(t),
        const SizedBox(height: 12),
        Center(child: SizedBox(height: 190, child: FittedBox(child: _lamp()))),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.of(context).size.width >= 900;
    return Scaffold(
      backgroundColor: Palette.dark.hero,
      body: Listener(
        onPointerHover: (e) => _track(e.position),
        onPointerMove: (e) => _track(e.position),
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(end: _lit ? 1.0 : 0.0),
          duration: Duration(milliseconds: Fx.enabled ? 250 : 0),
          builder: (context, t, _) => DarkScene(lit: t, child: SafeArea(child: wide ? _wide(t) : _narrow(t))),
        ),
      ),
    );
  }
}