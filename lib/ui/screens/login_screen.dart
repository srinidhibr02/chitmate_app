library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/auth_service.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../widgets/animated_bits.dart';
import '../widgets/common.dart';

/// Sign in with a mobile number and a one-time code. Once signed in the
/// person stays logged in, so this is only shown the first time (or after
/// signing out).
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  static const int _codeLength = 6;
  static const int _resendSeconds = 30;

  final TextEditingController _phone = TextEditingController();
  final TextEditingController _code = TextEditingController();
  PhoneChallenge? _challenge;
  bool _busy = false;
  String? _error;
  int _sendCount = 0;

  @override
  void dispose() {
    _phone.dispose();
    _code.dispose();
    super.dispose();
  }

  String _digits() => _phone.text.replaceAll(RegExp(r'\D'), '');

  Future<void> _send() async {
    if (_busy) return;
    final auth = AppScope.of(context).auth;
    if (auth == null) return;
    final digits = _digits();
    if (!RegExp(r'^[6-9]\d{9}$').hasMatch(digits)) {
      setState(() => _error = 'Enter a valid 10-digit mobile number.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final challenge = await auth.sendCode('+91$digits');
      if (!mounted) return;
      setState(() {
        _challenge = challenge;
        _busy = false;
        _sendCount++;
        _code.clear();
      });
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'Could not send the code. Check your connection and try again.';
      });
    }
  }

  Future<void> _verify() async {
    if (_busy) return;
    final auth = AppScope.of(context).auth;
    final challenge = _challenge;
    if (auth == null || challenge == null) return;
    final code = _code.text.trim();
    if (code.length != _codeLength) {
      setState(() => _error = 'Enter the $_codeLength-digit code.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await auth.confirmCode(challenge, code);
      // The app moves on by itself once the sign-in is reported.
      if (!mounted) return;
      setState(() => _busy = false);
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'Could not check the code. Check your connection and try again.';
      });
    }
  }

  void _changeNumber() {
    setState(() {
      _challenge = null;
      _error = null;
      _code.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final challenge = _challenge;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  const FadeSlide(child: Center(child: AppLogo(size: 96))),
                  const SizedBox(height: 20),
                  FadeSlide(
                    index: 1,
                    child: Text(
                      challenge == null ? 'Welcome to ChitMate' : 'Enter the code',
                      textAlign: TextAlign.center,
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w900),
                    ),
                  ),
                  const SizedBox(height: 8),
                  FadeSlide(
                    index: 2,
                    child: Text(
                      challenge == null
                          ? 'Sign in with your mobile number. We will text you a code.'
                          : 'We sent a $_codeLength-digit code to ${challenge.phone}.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: scheme.onSurfaceVariant, height: 1.4),
                    ),
                  ),
                  const SizedBox(height: 24),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: challenge == null ? _phoneStep(context) : _codeStep(context),
                  ),
                  if (_error != null) ...<Widget>[
                    const SizedBox(height: 12),
                    NoticeBanner(
                      text: _error!,
                      icon: Icons.error_outline_rounded,
                      color: scheme.error,
                    ),
                  ],
                  const SizedBox(height: 20),
                  Text(
                    'ChitMate helps you keep track of a chit group. It never collects '
                    'or sends money.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12, height: 1.4),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _phoneStep(BuildContext context) {
    return Column(
      key: const ValueKey<String>('phone-step'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        TextField(
          key: const Key('phone-field'),
          controller: _phone,
          keyboardType: TextInputType.phone,
          autofocus: true,
          maxLength: 10,
          inputFormatters: <TextInputFormatter>[FilteringTextInputFormatter.digitsOnly],
          onSubmitted: (_) => _send(),
          decoration: appInput(context, label: 'Mobile number', prefixText: '+91  ')
              .copyWith(counterText: ''),
        ),
        const SizedBox(height: 16),
        FilledButton(
          key: const Key('send-code'),
          onPressed: _busy ? null : _send,
          child: _busy ? const _Spinner() : const Text('Send code'),
        ),
      ],
    );
  }

  Widget _codeStep(BuildContext context) {
    return Column(
      key: const ValueKey<String>('code-step'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        TextField(
          key: const Key('code-field'),
          controller: _code,
          keyboardType: TextInputType.number,
          autofocus: true,
          maxLength: _codeLength,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: 8),
          inputFormatters: <TextInputFormatter>[FilteringTextInputFormatter.digitsOnly],
          onChanged: (v) {
            if (v.length == _codeLength) _verify();
          },
          decoration: appInput(context, label: 'Code').copyWith(counterText: ''),
        ),
        const SizedBox(height: 16),
        FilledButton(
          key: const Key('verify-code'),
          onPressed: _busy ? null : _verify,
          child: _busy ? const _Spinner() : const Text('Verify and continue'),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            TextButton(
              key: const Key('change-number'),
              onPressed: _busy ? null : _changeNumber,
              child: const Text('Change number'),
            ),
            TweenAnimationBuilder<double>(
              key: ValueKey<int>(_sendCount),
              tween: Tween<double>(begin: 0, end: 1),
              duration: const Duration(seconds: _resendSeconds),
              builder: (context, v, _) {
                if (v < 1) {
                  final left = (_resendSeconds * (1 - v)).ceil();
                  return Text('Resend in ${left}s',
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant));
                }
                return TextButton(
                  key: const Key('resend-code'),
                  onPressed: _busy ? null : _send,
                  child: const Text('Resend code'),
                );
              },
            ),
          ],
        ),
      ],
    );
  }
}

class _Spinner extends StatelessWidget {
  const _Spinner();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 20,
      height: 20,
      child: CircularProgressIndicator(strokeWidth: 2.5),
    );
  }
}
