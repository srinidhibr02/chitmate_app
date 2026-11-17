library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/auth_service.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../widgets/common.dart';

/// Deleting an account needs a second check: a new code is sent to the
/// person's own number and must be entered before anything is deleted.
class DeleteAccountScreen extends StatefulWidget {
  const DeleteAccountScreen({super.key});

  @override
  State<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends State<DeleteAccountScreen> {
  static const int _codeLength = 6;

  final TextEditingController _code = TextEditingController();
  PhoneChallenge? _challenge;
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    final state = AppScope.of(context);
    final auth = state.auth;
    final user = state.user;
    if (auth == null || user == null || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final challenge = await auth.sendCode(user.phone);
      if (!mounted) return;
      setState(() {
        _challenge = challenge;
        _busy = false;
        _code.clear();
      });
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.message;
      });
    } catch (e) {
      debugPrint('Sending the code failed: $e');
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'Could not send the code. Check your connection and try again.';
      });
    }
  }

  Future<void> _delete() async {
    final state = AppScope.of(context);
    final auth = state.auth;
    final challenge = _challenge;
    final user = state.user;
    if (auth == null || challenge == null || user == null || _busy) return;
    final code = _code.text.trim();
    if (code.length != _codeLength) {
      setState(() => _error = 'Enter the $_codeLength-digit code.');
      return;
    }
    final navigator = Navigator.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final signedIn = await auth.confirmCode(challenge, code);
      if (signedIn.uid != user.uid) {
        throw const AuthException('That code is for a different account.');
      }
      final err = await state.deleteAccount();
      if (!mounted) return;
      if (err != null) {
        setState(() {
          _busy = false;
          _error = err;
        });
        return;
      }
      navigator.popUntil((r) => r.isFirst);
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.message;
      });
    } catch (e) {
      debugPrint('Deleting the account failed: $e');
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'Could not delete your account. Check your connection and try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final scheme = Theme.of(context).colorScheme;
    final phone = state.user?.phone ?? '';
    final groups = state.groups.where((g) => g.adminUid == state.user?.uid).length;

    return Scaffold(
      appBar: AppBar(title: const Text('Delete account')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: <Widget>[
            NoticeBanner(
              icon: Icons.warning_amber_rounded,
              color: scheme.error,
              text: 'This permanently deletes your sign-in and '
                  '${groups == 0 ? 'every group you organise' : plural2(groups)}, with all '
                  'members, chits, votes and results. It cannot be undone. Groups run by '
                  'someone else are not affected.',
            ),
            const SizedBox(height: 16),
            if (_challenge == null) ...<Widget>[
              Text(
                'To make sure it is really you, we will text a code to $phone.',
                style: TextStyle(color: scheme.onSurfaceVariant, height: 1.4),
              ),
              const SizedBox(height: 16),
              FilledButton(
                key: const Key('send-delete-code'),
                onPressed: _busy ? null : _sendCode,
                child: Text(_busy ? 'Sending…' : 'Send code'),
              ),
            ] else ...<Widget>[
              Text(
                'Enter the code we sent to $phone.',
                style: TextStyle(color: scheme.onSurfaceVariant, height: 1.4),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('delete-code-field'),
                controller: _code,
                keyboardType: TextInputType.number,
                maxLength: _codeLength,
                autofocus: true,
                inputFormatters: <TextInputFormatter>[FilteringTextInputFormatter.digitsOnly],
                decoration: appInput(context, label: 'Code'),
              ),
              const SizedBox(height: 8),
              FilledButton(
                key: const Key('confirm-delete'),
                style: FilledButton.styleFrom(
                  backgroundColor: scheme.error,
                  foregroundColor: scheme.onError,
                ),
                onPressed: _busy ? null : _delete,
                child: Text(_busy ? 'Deleting…' : 'Delete my account'),
              ),
              TextButton(
                key: const Key('resend-delete-code'),
                onPressed: _busy ? null : _sendCode,
                child: const Text('Send the code again'),
              ),
            ],
            if (_error != null) ...<Widget>[
              const SizedBox(height: 12),
              NoticeBanner(
                key: const Key('delete-error'),
                text: _error!,
                icon: Icons.error_outline_rounded,
                color: scheme.error,
              ),
            ],
          ],
        ),
      ),
    );
  }

  static String plural2(int n) => n == 1 ? 'the 1 group you organise' : 'the $n groups you organise';
}
