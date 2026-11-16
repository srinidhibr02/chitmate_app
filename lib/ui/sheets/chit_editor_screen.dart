library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/format.dart';
import '../../domain/models.dart';
import '../../domain/rules.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../screens/group_helpers.dart';
import '../widgets/common.dart';

/// Creates a chit, or edits [chitId]: tick the owners and enter how much each
/// puts in. The amounts must add up to the chit value.
class ChitEditorScreen extends StatefulWidget {
  const ChitEditorScreen({super.key, required this.groupId, this.chitId});

  final String groupId;
  final String? chitId;

  @override
  State<ChitEditorScreen> createState() => _ChitEditorScreenState();
}

class _ChitEditorScreenState extends State<ChitEditorScreen> {
  final Map<String, TextEditingController> _amounts = <String, TextEditingController>{};
  final Set<String> _checked = <String>{};
  bool _initialised = false;
  bool _agreed = false;
  bool _saving = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialised) return;
    _initialised = true;
    final g = AppScope.of(context).groupById(widget.groupId);
    if (g == null) return;
    final chit = widget.chitId == null ? null : g.chitById(widget.chitId!);
    for (final m in g.members) {
      final share = chit?.shares[m.id];
      if (m.left && share == null) continue;
      _amounts[m.id] = TextEditingController(text: share == null ? '' : '$share');
      if (share != null) _checked.add(m.id);
    }
  }

  @override
  void dispose() {
    for (final c in _amounts.values) {
      c.dispose();
    }
    super.dispose();
  }

  int _amountOf(String id) => int.tryParse(_amounts[id]?.text.trim() ?? '') ?? 0;

  Map<String, int> _shares() {
    final out = <String, int>{};
    for (final id in _checked) {
      final n = _amountOf(id);
      if (n > 0) out[id] = n;
    }
    return out;
  }

  int _total() => _shares().values.fold<int>(0, (a, b) => a + b);

  void _splitEqually(ChitGroup g) {
    final chit = widget.chitId == null ? null : g.chitById(widget.chitId!);
    final ids = _choosable(g, chit).where((m) => _checked.contains(m.id)).map((m) => m.id).toList();
    final value = g.chitValue ?? 0;
    final parts = Rules.equalSplit(value, ids.length);
    setState(() {
      for (var i = 0; i < ids.length; i++) {
        _amounts[ids[i]]!.text = '${parts[i]}';
      }
    });
  }

  void _fillRest(ChitGroup g, String id) {
    final value = g.chitValue ?? 0;
    final others = _total() - _amountOf(id);
    final rest = value - others;
    setState(() {
      _checked.add(id);
      _amounts[id]!.text = rest > 0 ? '$rest' : '';
    });
  }

  /// Members who can be chosen as owners: everyone in the group, plus anyone
  /// who left but still holds a share of this chit.
  List<Member> _choosable(ChitGroup g, Chit? chit) => g.members
      .where((m) => !m.left || (chit?.ownedBy(m.id) ?? false))
      .toList();

  Future<void> _save(ChitGroup g) async {
    final navigator = Navigator.of(context);
    final shares = _shares();
    final chitId = widget.chitId;
    setState(() => _saving = true);
    final err = await tryAction(context, g.id, (group, a, actor) {
      if (chitId == null) {
        a.addChit(group, shares, actor: actor);
      } else {
        a.updateChitShares(group, chitId, shares, actor: actor, coOwnersAgreed: _agreed);
      }
    });
    if (!mounted) return;
    setState(() => _saving = false);
    if (err != null) {
      showSnack(context, err, error: true);
      return;
    }
    navigator.pop();
  }

  Future<void> _remove(ChitGroup g, Chit chit) async {
    final ok = await confirmDialog(
      context,
      title: 'Remove Chit ${chit.number}?',
      message: 'The chit and its shares will be deleted.',
      confirmLabel: 'Remove',
      destructive: true,
    );
    if (!ok || !mounted) return;
    final navigator = Navigator.of(context);
    final err = await tryAction(context, g.id, (group, a, actor) {
      a.removeChit(group, chit.id, actor: actor);
    });
    if (!mounted) return;
    if (err != null) {
      showSnack(context, err, error: true);
      return;
    }
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final g = state.groupById(widget.groupId);
    if (g == null) {
      return Scaffold(appBar: AppBar(), body: const SizedBox.shrink());
    }
    final chit = widget.chitId == null ? null : g.chitById(widget.chitId!);
    final value = g.chitValue ?? 0;
    final scheme = Theme.of(context).colorScheme;
    final shares = _shares();
    final total = _total();
    final error = g.chitValue == null ? 'Set the chit value first.' : Rules.sharesError(g, shares);
    final needsConsent = g.started && chit != null;
    final canSave = error == null && (!needsConsent || _agreed) && !_saving;
    final Color statusColor = total == value && error == null
        ? AppColors.success
        : (total > value ? scheme.error : AppColors.warning);

    return Scaffold(
      appBar: AppBar(
        title: Text(chit == null ? 'New chit' : 'Edit Chit ${chit.number}'),
        actions: <Widget>[
          if (chit != null && !g.started)
            IconButton(
              tooltip: 'Remove this chit',
              icon: Icon(Icons.delete_outline_rounded, color: scheme.error),
              onPressed: () => _remove(g, chit),
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                children: <Widget>[
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            const Expanded(
                              child: Text('Chit value',
                                  style: TextStyle(fontWeight: FontWeight.w700)),
                            ),
                            Text(rupees(value),
                                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: TweenAnimationBuilder<double>(
                            tween: Tween<double>(
                              begin: 0,
                              end: value == 0 ? 0 : (total / value).clamp(0.0, 1.0).toDouble(),
                            ),
                            duration: const Duration(milliseconds: 300),
                            builder: (context, v, _) => LinearProgressIndicator(
                              value: v,
                              minHeight: 12,
                              color: statusColor,
                              backgroundColor: statusColor.withAlpha(34),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          '${rupees(total)} of ${rupees(value)} assigned',
                          key: const Key('assigned-text'),
                          style: TextStyle(color: statusColor, fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          error ?? 'The shares add up. Ready to save.',
                          key: const Key('shares-message'),
                          style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  SectionHeader(
                    'Who owns this chit?',
                    subtitle: 'Tick the owners and enter what each puts in every month.',
                    trailing: TextButton.icon(
                      onPressed: _checked.isEmpty ? null : () => _splitEqually(g),
                      icon: const Icon(Icons.balance_rounded, size: 18),
                      label: const Text('Split equally'),
                    ),
                  ),
                  if (_choosable(g, chit).isEmpty)
                    const NoticeBanner(text: 'Add members first, then come back to create chits.'),
                  for (final m in _choosable(g, chit))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _OwnerRow(
                        name: m.left ? '${m.name} (left)' : m.name,
                        checked: _checked.contains(m.id),
                        controller: _amounts[m.id]!,
                        onChecked: (v) => setState(() {
                          if (v) {
                            _checked.add(m.id);
                          } else {
                            _checked.remove(m.id);
                            _amounts[m.id]!.text = '';
                          }
                        }),
                        onChanged: () => setState(() {}),
                        onFill: () => _fillRest(g, m.id),
                      ),
                    ),
                  if (needsConsent) ...<Widget>[
                    const SizedBox(height: 8),
                    NoticeBanner(
                      icon: Icons.handshake_rounded,
                      color: AppColors.warning,
                      text: 'The cycle has started. Changing who owns this chit affects what '
                          'people pay and receive, so everyone involved must agree first.',
                      action: CheckboxListTile(
                        key: const Key('consent-checkbox'),
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        value: _agreed,
                        onChanged: (v) => setState(() => _agreed = v ?? false),
                        title: const Text('Everyone affected has agreed'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  key: const Key('save-chit'),
                  onPressed: canSave ? () => _save(g) : null,
                  child: Text(chit == null ? 'Add chit' : 'Save changes'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OwnerRow extends StatelessWidget {
  const _OwnerRow({
    required this.name,
    required this.checked,
    required this.controller,
    required this.onChecked,
    required this.onChanged,
    required this.onFill,
  });

  final String name;
  final bool checked;
  final TextEditingController controller;
  final ValueChanged<bool> onChecked;
  final VoidCallback onChanged;
  final VoidCallback onFill;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.fromLTRB(8, 8, 12, 8),
      child: Row(
        children: <Widget>[
          Checkbox(value: checked, onChanged: (v) => onChecked(v ?? false)),
          MemberAvatar(name: name, size: 36),
          const SizedBox(width: 10),
          Expanded(
            child: Text(name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
          SizedBox(
            width: 112,
            child: TextField(
              controller: controller,
              enabled: checked,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.right,
              inputFormatters: <TextInputFormatter>[FilteringTextInputFormatter.digitsOnly],
              onChanged: (_) => onChanged(),
              decoration: const InputDecoration(
                prefixText: '₹ ',
                isDense: true,
                border: OutlineInputBorder(),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Fill the rest',
            onPressed: onFill,
            icon: const Icon(Icons.auto_fix_high_rounded, size: 20),
          ),
        ],
      ),
    );
  }
}
