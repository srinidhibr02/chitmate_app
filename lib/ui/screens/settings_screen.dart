library;

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/links.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../widgets/common.dart';
import 'delete_account_screen.dart';
import 'faq_screen.dart';
import 'rules_screen.dart';

/// Your name, help, legal pages, sign out and account deletion.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final scheme = Theme.of(context).colorScheme;
    final signedIn = state.auth != null && state.user != null;
    final name = state.profile?.name ?? '';

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: <Widget>[
            AppCard(
              child: Row(
                children: <Widget>[
                  MemberAvatar(name: name.isEmpty ? '?' : name, size: 52),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(name.isEmpty ? 'Your name' : name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
                        if (signedIn)
                          Text(state.user!.phone,
                              key: const Key('settings-phone'),
                              style: TextStyle(color: scheme.onSurfaceVariant)),
                      ],
                    ),
                  ),
                  TextButton(
                    key: const Key('edit-name'),
                    onPressed: () => showAppSheet<void>(context, (_) => const _EditNameSheet()),
                    child: const Text('Edit'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            const SectionHeader('Help'),
            _Tile(
              key: const Key('open-faq'),
              icon: Icons.quiz_outlined,
              title: 'FAQ',
              subtitle: 'Answers to common questions',
              onTap: () => Navigator.of(context).push(softRoute<void>(const FaqScreen())),
            ),
            _Tile(
              icon: Icons.menu_book_outlined,
              title: 'How ChitMate works',
              subtitle: 'The rules, step by step',
              onTap: () => Navigator.of(context).push(softRoute<void>(const RulesScreen())),
            ),
            _Tile(
              key: const Key('contact-support'),
              icon: Icons.support_agent_rounded,
              title: 'Contact support',
              subtitle: kSupportEmail,
              onTap: () => _mail(context, 'ChitMate support', 'Hi,\n\n'),
            ),
            _Tile(
              key: const Key('send-feedback'),
              icon: Icons.rate_review_outlined,
              title: 'Send feedback',
              subtitle: 'Tell us what to improve',
              onTap: () => _mail(
                context,
                'ChitMate feedback',
                'What I liked:\n\nWhat could be better:\n\n',
              ),
            ),
            const SectionHeader('About'),
            _Tile(
              key: const Key('open-privacy'),
              icon: Icons.privacy_tip_outlined,
              title: 'Privacy policy',
              onTap: () => _open(context, kPrivacyPolicyUrl),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(4, 4, 4, 0),
              child: Text(
                'ChitMate keeps records for your chit group. It never collects, holds or '
                'sends money.',
                style: TextStyle(fontSize: 12.5, height: 1.4),
              ),
            ),
            if (signedIn) ...<Widget>[
              const SizedBox(height: 8),
              const SectionHeader('Account'),
              _Tile(
                key: const Key('sign-out'),
                icon: Icons.logout_rounded,
                title: 'Sign out',
                onTap: () => _signOut(context),
              ),
              _Tile(
                key: const Key('delete-account'),
                icon: Icons.delete_forever_rounded,
                title: 'Delete account',
                subtitle: 'Permanently remove your account and groups',
                danger: true,
                onTap: () =>
                    Navigator.of(context).push(softRoute<void>(const DeleteAccountScreen())),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static Future<void> _signOut(BuildContext context) async {
    final state = AppScope.of(context);
    final navigator = Navigator.of(context);
    final ok = await confirmDialog(
      context,
      title: 'Sign out?',
      message: 'You will need a new code to sign in again.',
      confirmLabel: 'Sign out',
    );
    if (!ok) return;
    navigator.popUntil((r) => r.isFirst);
    await state.signOut();
  }

  static Future<void> _open(BuildContext context, String url) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      if (await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication)) return;
    } catch (e) {
      debugPrint('Could not open $url: $e');
    }
    messenger.showSnackBar(SnackBar(content: Text('Could not open the page. Visit $url')));
  }

  static Future<void> _mail(BuildContext context, String subject, String body) async {
    final messenger = ScaffoldMessenger.of(context);
    final uri = Uri.parse(
      'mailto:$kSupportEmail?subject=${Uri.encodeComponent(subject)}&body=${Uri.encodeComponent(body)}',
    );
    try {
      if (await launchUrl(uri)) return;
    } catch (e) {
      debugPrint('Could not open the mail app: $e');
    }
    messenger.showSnackBar(
      const SnackBar(content: Text('No mail app found. Write to $kSupportEmail')),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    super.key,
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.danger = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = danger ? scheme.error : scheme.onSurface;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AppCard(
        onTap: onTap,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: <Widget>[
            Icon(icon, color: danger ? scheme.error : AppColors.teal),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(title,
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: color)),
                  if (subtitle != null)
                    Text(subtitle!,
                        style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: scheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

class _EditNameSheet extends StatefulWidget {
  const _EditNameSheet();

  @override
  State<_EditNameSheet> createState() => _EditNameSheetState();
}

class _EditNameSheetState extends State<_EditNameSheet> {
  TextEditingController? _name;
  String? _error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _name ??= TextEditingController(text: AppScope.of(context).profile?.name ?? '');
  }

  @override
  void dispose() {
    _name?.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final navigator = Navigator.of(context);
    final err = await AppScope.of(context).setProfileName(_name!.text);
    if (!mounted) return;
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Your name',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(
            'This name is shown on the updates you post as organiser.',
            style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 18),
          TextField(
            key: const Key('name-field'),
            controller: _name,
            textCapitalization: TextCapitalization.words,
            maxLength: 40,
            decoration: appInput(context, label: 'Your name').copyWith(errorText: _error),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              key: const Key('save-name'),
              onPressed: _save,
              child: const Text('Save'),
            ),
          ),
        ],
      ),
    );
  }
}
