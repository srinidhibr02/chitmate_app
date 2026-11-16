library;

import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../domain/models.dart';
import '../../domain/notices.dart';
import '../../domain/rules.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../screens/group_helpers.dart';
import '../widgets/common.dart';

/// Records members' votes for the open month. The sheet stays open so the
/// admin can enter several votes in a row.
Future<void> showVoteSheet(BuildContext context, String groupId) {
  return showAppSheet<void>(context, (_) => _VoteSheet(groupId: groupId));
}

class _VoteSheet extends StatefulWidget {
  const _VoteSheet({required this.groupId});

  final String groupId;

  @override
  State<_VoteSheet> createState() => _VoteSheetState();
}

class _VoteSheetState extends State<_VoteSheet> {
  String? _voterId;
  String? _error;
  bool _busy = false;

  Future<void> _vote(ChitGroup g, Round r, String voterId, String targetId) async {
    final ok = await confirmDialog(
      context,
      title: 'Record this vote?',
      message: '${g.memberName(voterId)} votes for ${g.memberName(targetId)}. '
          'Votes cannot be changed afterwards.',
      confirmLabel: 'Record vote',
    );
    if (!ok || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final err = await tryAction(context, g.id, (group, a, actor) {
      a.castVote(group, r.index, voterId: voterId, targetId: targetId);
    });
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = err;
    });
    if (err == null) {
      final fresh = AppScope.of(context).groupById(g.id);
      final left = fresh == null ? 0 : Rules.votesLeft(fresh, fresh.rounds[r.index], voterId);
      if (left == 0) setState(() => _voterId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final g = state.groupById(widget.groupId);
    final cur = g?.currentRound;
    final scheme = Theme.of(context).colorScheme;
    if (g == null || cur == null || cur.status != RoundStatus.open) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Text('Voting is not open.'),
      );
    }
    final voterId = _voterId;
    final voters = g.members.where((m) => Rules.votingPower(g, m.id) > 0).toList();

    final children = <Widget>[];
    if (voterId == null) {
      children.addAll(<Widget>[
        Text('Whose vote?',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text(Notices.votingRules.join(' '),
            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13, height: 1.35)),
        const SizedBox(height: 12),
        for (final m in voters)
          Builder(builder: (context) {
            final power = Rules.votingPower(g, m.id);
            final targetsLeft = Rules.eligibleTargets(g, cur.index)
                .where((t) => !cur.votes.any((v) => v.voterId == m.id && v.targetId == t.id))
                .length;
            final left = Rules.votesLeft(g, cur, m.id);
            final canVote = left > 0 && targetsLeft > 0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: AppCard(
                onTap: !canVote ? null : () => setState(() => _voterId = m.id),
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: <Widget>[
                    MemberAvatar(name: m.name, size: 40),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(m.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                    ),
                    Pill(
                      label: !canVote ? 'All votes used' : '$left of $power left',
                      color: !canVote ? scheme.outline : AppColors.teal,
                    ),
                  ],
                ),
              ),
            );
          }),
      ]);
    } else {
      final targets = Rules.eligibleTargets(g, cur.index);
      final already = cur.votes.where((v) => v.voterId == voterId).map((v) => v.targetId).toSet();
      children.addAll(<Widget>[
        Row(
          children: <Widget>[
            IconButton(
              tooltip: 'Back',
              onPressed: () => setState(() {
                _voterId = null;
                _error = null;
              }),
              icon: const Icon(Icons.arrow_back_rounded),
            ),
            Expanded(
              child: Text('${g.memberName(voterId)} votes for…',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w800)),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(left: 12, bottom: 12),
          child: Text(
            '${plural(Rules.votesLeft(g, cur, voterId), 'vote')} left. A person can be '
            'chosen once. Voting for yourself is allowed once.',
            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
          ),
        ),
        for (final t in targets)
          Builder(builder: (context) {
            final used = already.contains(t.id);
            final chits = Rules.eligibleChitsOf(g, cur.index, t.id);
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: AppCard(
                onTap: (used || _busy) ? null : () => _vote(g, cur, voterId, t.id),
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: <Widget>[
                    MemberAvatar(name: t.name, size: 40),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(t.id == voterId ? '${t.name} (themselves)' : (t.left ? '${t.name} (left)' : t.name),
                              style: const TextStyle(fontWeight: FontWeight.w700)),
                          Text(
                            'Can win: ${chits.map((c) => 'Chit ${c.number}').join(', ')}',
                            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    if (used) const Pill(label: 'Already voted for', color: AppColors.success),
                  ],
                ),
              ),
            );
          }),
      ]);
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          ...children,
          if (_error != null) ...<Widget>[
            const SizedBox(height: 4),
            NoticeBanner(text: _error!, icon: Icons.error_outline_rounded, color: scheme.error),
          ],
          const SizedBox(height: 8),
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Done')),
        ],
      ),
    );
  }
}

/// Lets the admin settle a tie after talking with the group.
/// Returns true when a winner was recorded.
Future<bool> showTieBreakSheet(BuildContext context, String groupId) async {
  final done = await showAppSheet<bool>(context, (_) => _TieSheet(groupId: groupId));
  return done ?? false;
}

class _TieSheet extends StatefulWidget {
  const _TieSheet({required this.groupId});

  final String groupId;

  @override
  State<_TieSheet> createState() => _TieSheetState();
}

class _TieSheetState extends State<_TieSheet> {
  String? _choice;
  final TextEditingController _note = TextEditingController();
  String? _error;
  bool _busy = false;
  bool _lastGood = false;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _confirm(Round r) async {
    final choice = _choice;
    if (choice == null) return;
    final navigator = Navigator.of(context);
    setState(() {
      _busy = true;
      _lastGood = true;
      _error = null;
    });
    final err = await tryAction(context, widget.groupId, (g, a, actor) {
      a.adminResolveTie(g, r.index, memberId: choice, actor: actor, note: _note.text);
    });
    if (!mounted) return;
    if (err != null) {
      setState(() {
        _busy = false;
        _lastGood = false;
        _error = err;
      });
      return;
    }
    navigator.pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final g = AppScope.of(context).groupById(widget.groupId);
    final r = g?.currentRound;
    final scheme = Theme.of(context).colorScheme;
    if (_busy && _lastGood) return const SizedBox(height: 120);
    if (g == null || r == null || r.status != RoundStatus.awaitingTieBreak) {
      return const Padding(padding: EdgeInsets.all(24), child: Text('There is no tie to settle.'));
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text('Settle the tie',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(
            'Talk it through with the group, then choose who receives this month. '
            'One of their eligible chits will be drawn at random.',
            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13, height: 1.35),
          ),
          const SizedBox(height: 12),
          for (final id in r.tiedMemberIds)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: AppCard(
                onTap: () => setState(() => _choice = id),
                color: _choice == id ? AppColors.teal.withAlpha(30) : null,
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: <Widget>[
                    MemberAvatar(name: g.memberName(id), size: 40),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(g.memberName(id),
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                    ),
                    Icon(
                      _choice == id
                          ? Icons.check_circle_rounded
                          : Icons.radio_button_unchecked_rounded,
                      color: _choice == id ? AppColors.teal : scheme.outline,
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 4),
          TextField(
            controller: _note,
            maxLength: 200,
            decoration: appInput(context, label: 'Reason (optional)', hint: 'Agreed on the group call'),
          ),
          if (_error != null)
            NoticeBanner(text: _error!, icon: Icons.error_outline_rounded, color: scheme.error),
          const SizedBox(height: 12),
          FilledButton(
            key: const Key('confirm-tie'),
            onPressed: (_choice == null || _busy) ? null : () => _confirm(r),
            child: const Text('Confirm winner'),
          ),
        ],
      ),
    );
  }
}

/// Lets the admin record the chit the group agreed on.
/// Returns true when a winner was recorded.
Future<bool> showManualPickSheet(BuildContext context, String groupId) async {
  final done = await showAppSheet<bool>(context, (_) => _ManualSheet(groupId: groupId));
  return done ?? false;
}

class _ManualSheet extends StatefulWidget {
  const _ManualSheet({required this.groupId});

  final String groupId;

  @override
  State<_ManualSheet> createState() => _ManualSheetState();
}

class _ManualSheetState extends State<_ManualSheet> {
  String? _choice;
  final TextEditingController _note = TextEditingController();
  String? _error;
  bool _busy = false;
  bool _lastGood = false;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _confirm(Round r) async {
    final choice = _choice;
    if (choice == null) return;
    final navigator = Navigator.of(context);
    setState(() {
      _busy = true;
      _lastGood = true;
      _error = null;
    });
    final err = await tryAction(context, widget.groupId, (g, a, actor) {
      a.manualPick(g, r.index, chitId: choice, actor: actor, note: _note.text);
    });
    if (!mounted) return;
    if (err != null) {
      setState(() {
        _busy = false;
        _lastGood = false;
        _error = err;
      });
      return;
    }
    navigator.pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final g = AppScope.of(context).groupById(widget.groupId);
    final r = g?.currentRound;
    final scheme = Theme.of(context).colorScheme;
    if (_busy && _lastGood) return const SizedBox(height: 120);
    if (g == null || r == null || r.status != RoundStatus.open) {
      return const Padding(padding: EdgeInsets.all(24), child: Text('This month is not open.'));
    }
    final elig = Rules.eligibility(g, r.index);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text('Which chit did the group pick?',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          for (final c in elig.chits)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: AppCard(
                onTap: () => setState(() => _choice = c.id),
                color: _choice == c.id ? AppColors.teal.withAlpha(30) : null,
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text('Chit ${c.number}',
                              style: const TextStyle(fontWeight: FontWeight.w800)),
                          Text(
                            c.shares.entries
                                .map((e) => '${g.memberName(e.key)} ${rupees(e.value)}')
                                .join('  ·  '),
                            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      _choice == c.id
                          ? Icons.check_circle_rounded
                          : Icons.radio_button_unchecked_rounded,
                      color: _choice == c.id ? AppColors.teal : scheme.outline,
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 4),
          TextField(
            controller: _note,
            maxLength: 200,
            decoration: appInput(context, label: 'Note (optional)'),
          ),
          if (_error != null)
            NoticeBanner(text: _error!, icon: Icons.error_outline_rounded, color: scheme.error),
          const SizedBox(height: 12),
          FilledButton(
            key: const Key('confirm-pick'),
            onPressed: (_choice == null || _busy) ? null : () => _confirm(r),
            child: const Text('Record this chit'),
          ),
        ],
      ),
    );
  }
}
