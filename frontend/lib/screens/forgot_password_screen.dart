import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../api/auth_service.dart';
import '../state/providers.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/fx.dart';

final _mailRe = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _code = TextEditingController();
  final _password = TextEditingController();
  int _step = 0; // 0 = ask for email, 1 = enter code and new password
  bool _busy = false;
  bool _obscure = true;
  String? _error;
  String? _info;

  @override
  void dispose() {
    _email.dispose();
    _code.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _send({bool resend = false}) async {
    if (_busy) return;
    if (!resend && !_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
      _info = null;
    });
    try {
      await ref.read(authServiceProvider).sendPasswordReset(_email.text.trim());
      if (mounted) {
        setState(() {
          _step = 1;
          _info = 'If an account exists for ${_email.text.trim()}, a 6-digit code is on its way. It can take a minute.';
        });
      }
    } on AuthFailure catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reset() async {
    if (_busy || !_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
      _info = null;
    });
    final auth = ref.read(authServiceProvider);
    try {
      await auth.verifyResetCode(_email.text.trim(), _code.text.trim());
      await auth.updatePassword(_password.text);
      if (mounted) context.go('/projects');
    } on AuthFailure catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  List<Widget> _stepEmail() => [
        Text('Forgot your password?', style: display(28)),
        const SizedBox(height: 6),
        const Text('Enter your email and we will send you a 6-digit code.', style: TextStyle(color: Tk.mute, height: 1.4)),
        const SizedBox(height: 20),
        TextFormField(
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.email],
          textInputAction: TextInputAction.done,
          onFieldSubmitted: (_) => _send(),
          decoration: fieldDecoration('Email'),
          validator: (v) => (v == null || !_mailRe.hasMatch(v.trim())) ? 'Enter a valid email address.' : null,
        ),
        const SizedBox(height: 18),
        FilledButton(
          onPressed: _busy ? null : _send,
          child: _busy ? _spinner() : const Text('Send code'),
        ),
      ];

  List<Widget> _stepCode() => [
        Text('Check your inbox', style: display(28)),
        const SizedBox(height: 6),
        const Text('Enter the code from the email and choose a new password.', style: TextStyle(color: Tk.mute, height: 1.4)),
        const SizedBox(height: 20),
        TextFormField(
          controller: _code,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(8)],
          decoration: fieldDecoration('Code from email', hint: '123456'),
          validator: (v) => (v == null || v.trim().length < 6) ? 'Enter the 6-digit code.' : null,
        ),
        const SizedBox(height: 14),
        TextFormField(
          controller: _password,
          obscureText: _obscure,
          autofillHints: const [AutofillHints.newPassword],
          textInputAction: TextInputAction.done,
          onFieldSubmitted: (_) => _reset(),
          decoration: fieldDecoration(
            'New password',
            helper: 'At least 8 characters.',
            suffix: IconButton(
              tooltip: _obscure ? 'Show password' : 'Hide password',
              icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
              onPressed: () => setState(() => _obscure = !_obscure),
            ),
          ),
          validator: (v) => (v == null || v.length < 8) ? 'Use at least 8 characters.' : null,
        ),
        const SizedBox(height: 18),
        FilledButton(
          onPressed: _busy ? null : _reset,
          child: _busy ? _spinner() : const Text('Reset password'),
        ),
        const SizedBox(height: 6),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          TextButton(onPressed: _busy ? null : () => _send(resend: true), child: const Text('Resend code')),
          TextButton(
            onPressed: _busy
                ? null
                : () => setState(() {
                      _step = 0;
                      _error = null;
                      _info = null;
                    }),
            child: const Text('Use a different email'),
          ),
        ]),
      ];

  Widget _spinner() =>
      const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(children: [
        const Positioned.fill(child: AmbientBlobs(colors: [Tk.ultra, Tk.pink, Tk.sodium], opacity: 0.16)),
        Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Wordmark(size: 26),
                const SizedBox(height: 24),
                Reveal(
                  child: Panel(
                    padding: const EdgeInsets.all(28),
                    child: Form(
                      key: _form,
                      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                        if (_info != null) ...[InlineMessage(MsgKind.success, _info!), const SizedBox(height: 14)],
                        if (_error != null) ...[InlineMessage(MsgKind.error, _error!), const SizedBox(height: 14)],
                        ..._step == 0 ? _stepEmail() : _stepCode(),
                        const SizedBox(height: 4),
                        TextButton(
                          onPressed: _busy ? null : () => context.go('/login'),
                          child: const Text('Back to sign in'),
                        ),
                      ]),
                    ),
                  ),
                ),
              ]),
            ),
          ),
        ),
      ]),
    );
  }
}