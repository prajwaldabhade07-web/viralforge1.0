import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../api/auth_service.dart';
import '../state/providers.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/film.dart';
import '../widgets/frame_strip.dart';

final _emailRe = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _register = false;
  bool _busy = false;
  bool _obscure = true;
  String? _error;
  String? _info;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
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
    try {
      if (_register) {
        final needsConfirm = await auth.register(_email.text.trim(), _password.text);
        if (needsConfirm && mounted) {
          setState(() {
            _register = false;
            _info = 'Account created. Check your inbox to confirm your email, then sign in.';
          });
        }
      } else {
        await auth.signIn(_email.text.trim(), _password.text);
      }
    } on AuthFailure catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _hero(bool wide) {
    final p = context.pal;
    final ty = context.ty;
    return ClipRect(
      child: Container(
        color: p.hero,
        child: Stack(children: [
          GrainOverlay(color: p.onHero.withValues(alpha: 0.05)),
          Padding(
            padding: EdgeInsets.all(wide ? 56 : 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: wide ? MainAxisAlignment.center : MainAxisAlignment.start,
              mainAxisSize: wide ? MainAxisSize.max : MainAxisSize.min,
              children: [
                Wordmark(color: p.onHero, size: 24),
                SizedBox(height: wide ? 56 : 24),
                Text('Know how your video will land before you post it.',
                    style: ty.display.copyWith(fontSize: wide ? 52 : 30, color: p.onHero)),
                const SizedBox(height: 20),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: Text(
                    'Upload a short clip. Get five scores, specific fixes, and ten simulated viewer reactions for Instagram Reels, TikTok or YouTube Shorts.',
                    style: ty.body.copyWith(color: p.heroMute, fontSize: 16),
                  ),
                ),
                if (wide) ...[
                  const SizedBox(height: 40),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 460),
                    child: FrameStrip(
                        value: 72, height: 22, perforated: true, animate: false, trackColor: p.heroTrack, semanticLabel: 'Sample score meter'),
                  ),
                ],
              ],
            ),
          ),
        ]),
      ),
    );
  }

  Widget _formPanel() {
    final p = context.pal;
    final ty = context.ty;
    final notice = ref.watch(sessionNoticeProvider);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Form(
            key: _form,
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text(_register ? 'Create your account' : 'Sign in', style: ty.title),
              const SizedBox(height: 6),
              Text(_register ? 'Free to start. Use any email you can access.' : 'Welcome back.', style: ty.body.copyWith(color: p.mute)),
              const SizedBox(height: 22),
              if (notice != null) ...[InlineMessage(MsgKind.info, notice), const SizedBox(height: 14)],
              if (_info != null) ...[InlineMessage(MsgKind.success, _info!), const SizedBox(height: 14)],
              if (_error != null) ...[InlineMessage(MsgKind.error, _error!), const SizedBox(height: 14)],
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                textInputAction: TextInputAction.next,
                decoration: fieldDecoration(context, 'Email'),
                validator: (v) => (v == null || !_emailRe.hasMatch(v.trim())) ? 'Enter a valid email address.' : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _password,
                obscureText: _obscure,
                autofillHints: [_register ? AutofillHints.newPassword : AutofillHints.password],
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _submit(),
                decoration: fieldDecoration(
                  context,
                  'Password',
                  helper: _register ? 'At least 8 characters.' : null,
                  suffix: IconButton(
                    tooltip: _obscure ? 'Show password' : 'Hide password',
                    icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Enter your password.';
                  if (_register && v.length < 8) return 'Use at least 8 characters.';
                  return null;
                },
              ),
              if (!_register)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _busy ? null : () => context.go('/forgot-password'),
                    child: const Text('Forgot password?'),
                  ),
                )
              else
                const SizedBox(height: 8),
              const SizedBox(height: 14),
              FilledButton(
                onPressed: _busy ? null : _submit,
                child: _busy
                    ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5, color: p.onUltra))
                    : Text(_register ? 'Create account' : 'Sign in'),
              ),
              const SizedBox(height: 10),
              TextButton(
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
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.of(context).size.width >= 900;
    return Scaffold(
      body: wide
          ? Row(children: [Expanded(flex: 5, child: _hero(true)), Expanded(flex: 4, child: _formPanel())])
          : SingleChildScrollView(
              child: Column(children: [_hero(false), SizedBox(height: 560, child: _formPanel())]),
            ),
    );
  }
}