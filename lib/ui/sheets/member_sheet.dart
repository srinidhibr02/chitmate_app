library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/phone.dart';
import '../../domain/actions.dart';
import '../../domain/models.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../screens/group_helpers.dart';
import '../widgets/common.dart';

/// Adds a member, or edits [member] when given.
Future<void> showMemberSheet(BuildContext context, String groupId, {Member? member}) {
  return showAppSheet<void>(context, (_) => _MemberSheet(groupId: groupId, member: member));
}

class _MemberSheet extends StatefulWidget {
  const _MemberSheet({required this.groupId, this.member});

  final String groupId;
  final Member? member;

  @override
  State<_MemberSheet> createState() => _MemberSheetState();
}

class _MemberSheetState extends State<_MemberSheet> {
  late final TextEditingController _name = TextEditingController(text: widget.member?.name ?? '');
  late final TextEditingController _phone = TextEditingController(
      text: normalizeIndianMobile(widget.member?.phone ?? '')?.substring(3) ?? '');
  String? _error;
  bool _busy = false;

  bool get _editing => widget.member != null;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final navigator = Navigator.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    final member = widget.member;
    final err = await tryAction(context, widget.groupId, (g, a, actor) {
      if (member == null) {
        a.addMember(g, _name.text, phone: _phone.text, actor: actor);
      } else {
        a.renameMember(g, member.id, _name.text, phone: _phone.text, actor: actor);
      }
    });
    if (!mounted) return;
    if (err != null) {
      setState(() {
        _busy = false;
        _error = err;
      });
      return;
    }
    navigator.pop();
  }

  Future<void> _remove() async {
    final member = widget.member;
    if (member == null) return;
    final ok = await confirmDialog(
      context,
      title: 'Remove ${member.name}?',
      message: member.phone == null
          ? 'They will leave the group. Their chit shares stay on record, and you can add '
              'them back later from the former members list.'
          : 'They will leave the group. Their chit shares stay on record. Adding this phone '
              'number again restores them exactly as they were.',
      confirmLabel: 'Remove',
      destructive: true,
    );
    if (!ok || !mounted) return;
    final navigator = Navigator.of(context);
    final err = await tryAction(context, widget.groupId, (g, a, actor) {
      a.removeMember(g, member.id, actor: actor);
    });
    if (!mounted) return;
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final group = state.groupById(widget.groupId);
    final scheme = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(_editing ? 'Edit member' : 'Add a member',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 16),
          TextField(
            controller: _name,
            autofocus: !_editing,
            textCapitalization: TextCapitalization.words,
            maxLength: ChitActions.maxNameLength,
            decoration: appInput(context, label: 'Name'),
          ),
          const SizedBox(height: 4),
          TextField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            maxLength: 10,
            inputFormatters: <TextInputFormatter>[FilteringTextInputFormatter.digitsOnly],
            decoration: appInput(
              context,
              label: 'Mobile number',
              prefixText: '+91  ',
              helper: 'They sign in with this number to see the group and vote.',
            ).copyWith(counterText: ''),
          ),
          if (_error != null) ...<Widget>[
            const SizedBox(height: 4),
            NoticeBanner(text: _error!, icon: Icons.error_outline_rounded, color: scheme.error),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _busy ? null : _save,
              child: Text(_editing ? 'Save' : 'Add member'),
            ),
          ),
          if (_editing && group != null && !(widget.member?.left ?? false) && group.activeMembers.length > 1) ...<Widget>[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                onPressed: _busy ? null : _remove,
                icon: Icon(Icons.person_remove_rounded, color: scheme.error),
                label: Text('Remove from group', style: TextStyle(color: scheme.error)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
