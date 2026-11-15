library;

import 'package:flutter/material.dart';

import '../../core/dates.dart';
import '../../core/format.dart';
import '../../domain/actions.dart';
import '../../domain/labels.dart';
import '../../domain/models.dart';
import '../../domain/rules.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../sheets/result_dialog.dart';
import '../sheets/round_sheets.dart';
import '../widgets/animated_bits.dart';
import '../widgets/common.dart';
import 'group_helpers.dart';

/// The current month: choose how it is decided, then vote, pick or draw.
class RoundTab extends StatefulWidget {
  const RoundTab({super.key, required this.groupId});

  final String groupId;

  @override
  State<RoundTab> createState() => _RoundTabState();
}

class _RoundTabState extends State<RoundTab> {
  RoundMethod _method = RoundMethod.vote;
  TieBreakMode _tieBreak = TieBreakMode.auto;
  bool _busy = false;

  /// Runs [change]; if it decided the month, announces the winner.
  Future<void> _act(
    ChitGroup g,
    void Function(ChitGroup g, ChitActions a, String actor) change, {
    List<String>? reel,
  }) async {
    if (_busy) return;
    final cur = g.currentRound;
    if (cur == null) return;
    final index = cur.index;
    setState(() => _busy = true);
    final ok = await runAction(context, g.id, change);
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) await _announceIfDecided(g.id, index, reel: reel);
  }

  Future<void> _announceIfDecided(String groupId, int index, {List<String>? reel}) async {
    final fresh = AppScope.of(context).groupById(groupId);
    if (fresh == null || index >= fresh.rounds.length) return;
    final r = fresh.rounds[index];
    if (!r.isCompleted) return;
    await showResultDialog(context, fresh, r, reelCandidates: reel);
  }

  Future<void> _closeVoting(ChitGroup g) async {
    final cur = g.currentRound;
    if (cur == null) return;
    final ok = await confirmDialog(
      context,
      title: 'Close voting?',
      message: '${plural(cur.votes.length, 'vote')} recorded. '
          'No more votes can be added once voting is closed.',
      confirmLabel: 'Close voting',
    );
    if (!ok || !mounted) return;
    await _act(g, (group, a, actor) => a.closeVoting(group, cur.index, actor: actor));
  }

  Future<void> _settleTie(ChitGroup g) async {
    final index = g.currentRound?.index;
    final decided = await showTieBreakSheet(context, g.id);
    if (!decided || !mounted || index == null) return;
    await _announceIfDecided(g.id, index);
  }

  Future<void> _manual(ChitGroup g) async {
    final index = g.currentRound?.index;
    final decided = await showManualPickSheet(context, g.id);
    if (!decided || !mounted || index == null) return;
    await _announceIfDecided(g.id, index);
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final g = state.groupById(widget.groupId);
    if (g == null) return const SizedBox.shrink();
    if (!g.started) {
      return const EmptyState(
        title: 'The cycle has not started',
        message: 'Finish setting up on the Overview tab, then start the cycle. '
            'Each month will be decided here.',
        icon: Icons.hourglass_empty_rounded,
      );
    }
    final cur = g.currentRound;
    final done = g.rounds.where((r) => r.isCompleted).toList().reversed.toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: <Widget>[
        if (cur == null)
          const FadeSlide(
            child: NoticeBanner(
              icon: Icons.celebration_rounded,
              color: AppColors.success,
              text: 'Every month has been decided. The cycle is complete.',
            ),
          )
        else
          FadeSlide(child: _currentCard(context, g, cur, state.now)),
        if (done.isNotEmpty) ...<Widget>[
          const SizedBox(height: 8),
          const SectionHeader('Past months'),
          for (var i = 0; i < done.length; i++)
            FadeSlide(
              index: i,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _HistoryTile(group: g, round: done[i]),
              ),
            ),
        ],
      ],
    );
  }

  Widget _currentCard(BuildContext context, ChitGroup g, Round cur, DateTime now) {
    final scheme = Theme.of(context).colorScheme;
    final elig = Rules.eligibility(g, cur.index);
    final passed = dateOnly(now).isAfter(dateOnly(cur.announcementDate));
    final children = <Widget>[
      Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('Month ${cur.number} of ${g.rounds.length}',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.w900)),
                Text(
                  '${formatDateLong(cur.announcementDate)}  ·  '
                  '${countdownText(cur.announcementDate, now)}',
                  style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
                ),
              ],
            ),
          ),
          Pill(
            label: roundStatusLabel(cur.status),
            color: cur.status == RoundStatus.awaitingTieBreak ? AppColors.warning : AppColors.teal,
          ),
        ],
      ),
      const SizedBox(height: 14),
      _EligibilityBox(group: g, eligibility: elig),
      const SizedBox(height: 14),
    ];

    switch (cur.status) {
      case RoundStatus.pending:
        children.addAll(_pending(context, g, cur, passed));
      case RoundStatus.open:
        children.addAll(_open(context, g, cur));
      case RoundStatus.awaitingTieBreak:
        children.addAll(_tie(context, g, cur));
      case RoundStatus.completed:
        break;
    }
    return AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children));
  }

  // ----------------------------------------------------------- pending --

  List<Widget> _pending(BuildContext context, ChitGroup g, Round cur, bool passed) {
    final scheme = Theme.of(context).colorScheme;
    return <Widget>[
      const Text('How should this month be decided?',
          style: TextStyle(fontWeight: FontWeight.w800)),
      const SizedBox(height: 8),
      for (final m in RoundMethod.values)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _MethodTile(
            method: m,
            selected: _method == m,
            onTap: () => setState(() => _method = m),
          ),
        ),
      if (_method == RoundMethod.vote) ...<Widget>[
        const SizedBox(height: 4),
        const Text('If votes tie', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            for (final t in TieBreakMode.values)
              ChoiceChip(
                label: Text(tieBreakLabel(t)),
                selected: _tieBreak == t,
                onSelected: (_) => setState(() => _tieBreak = t),
              ),
          ],
        ),
      ],
      const SizedBox(height: 14),
      FilledButton.icon(
        key: const Key('open-round'),
        onPressed: _busy
            ? null
            : () => _act(
                  g,
                  (group, a, actor) => a.openRound(group, cur.index,
                      method: _method, tieBreak: _tieBreak, actor: actor),
                ),
        icon: const Icon(Icons.campaign_rounded),
        label: const Text('Open this month and notify'),
      ),
      if (passed) ...<Widget>[
        const SizedBox(height: 12),
        NoticeBanner(
          icon: Icons.schedule_rounded,
          color: AppColors.warning,
          text: 'The announcement date has passed and no method was chosen. '
              'As agreed, the app can now draw at random.',
          action: FilledButton.tonal(
            key: const Key('fallback-random'),
            onPressed: _busy
                ? null
                : () => _act(
                      g,
                      (group, a, actor) => a.fallbackRandom(group, cur.index, actor: actor),
                      reel: Rules.eligibility(g, cur.index)
                          .chits
                          .map(g.chitLabel)
                          .toList(),
                    ),
            child: const Text('Draw at random now'),
          ),
        ),
      ],
      if (!passed)
        Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Text(
            'If no method is chosen by the announcement date, a random draw can be used.',
            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
          ),
        ),
    ];
  }

  // -------------------------------------------------------------- open --

  List<Widget> _open(BuildContext context, ChitGroup g, Round cur) {
    final scheme = Theme.of(context).colorScheme;
    final header = <Widget>[
      Row(
        children: <Widget>[
          Icon(Icons.bolt_rounded, color: scheme.primary),
          const SizedBox(width: 8),
          Text(ChitActions.methodText(cur), style: const TextStyle(fontWeight: FontWeight.w800)),
        ],
      ),
      const SizedBox(height: 10),
    ];
    final method = cur.method;
    if (method == RoundMethod.manual) {
      return <Widget>[
        ...header,
        const Text('Once the group agrees on a chit, record it here.'),
        const SizedBox(height: 12),
        FilledButton.icon(
          key: const Key('pick-chit'),
          onPressed: _busy ? null : () => _manual(g),
          icon: const Icon(Icons.fact_check_rounded),
          label: const Text('Record the agreed chit'),
        ),
      ];
    }
    if (method == RoundMethod.random) {
      return <Widget>[
        ...header,
        const Text('Every eligible chit has the same chance. The draw happens once and '
            'the result is saved.'),
        const SizedBox(height: 12),
        FilledButton.icon(
          key: const Key('draw-now'),
          onPressed: _busy
              ? null
              : () => _act(
                    g,
                    (group, a, actor) => a.randomDraw(group, cur.index, actor: actor),
                    reel: Rules.eligibility(g, cur.index).chits.map(g.chitLabel).toList(),
                  ),
          icon: const Icon(Icons.casino_rounded),
          label: const Text('Draw now'),
        ),
      ];
    }
    // Vote.
    final outcome = Rules.tally(cur);
    final totalVotes = Rules.totalVotes(g);
    final entries = outcome.counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return <Widget>[
      ...header,
      Text(
        '${cur.votes.length} of $totalVotes votes recorded  ·  '
        'tie rule: ${tieBreakLabel(cur.tieBreak)}',
        style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
      ),
      const SizedBox(height: 10),
      if (entries.isEmpty)
        Text('No votes yet.', style: TextStyle(color: scheme.onSurfaceVariant)),
      for (final e in entries)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: <Widget>[
              SizedBox(
                width: 110,
                child: Text(g.memberName(e.key), maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween<double>(
                        begin: 0,
                        end: outcome.topVotes == 0 ? 0 : e.value / outcome.topVotes),
                    duration: const Duration(milliseconds: 300),
                    builder: (context, v, _) => LinearProgressIndicator(
                      value: v,
                      minHeight: 10,
                      backgroundColor: scheme.primary.withAlpha(24),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text('${e.value}', style: const TextStyle(fontWeight: FontWeight.w900)),
            ],
          ),
        ),
      const SizedBox(height: 12),
      FilledButton.icon(
        key: const Key('record-vote'),
        onPressed: _busy ? null : () => showVoteSheet(context, g.id),
        icon: const Icon(Icons.how_to_vote_rounded),
        label: const Text('Record a vote'),
      ),
      const SizedBox(height: 8),
      OutlinedButton.icon(
        key: const Key('close-voting'),
        onPressed: _busy ? null : () => _closeVoting(g),
        icon: const Icon(Icons.lock_clock_rounded),
        label: const Text('Close voting'),
      ),
    ];
  }

  // --------------------------------------------------------------- tie --

  List<Widget> _tie(BuildContext context, ChitGroup g, Round cur) {
    return <Widget>[
      NoticeBanner(
        icon: Icons.balance_rounded,
        color: AppColors.warning,
        text: '${cur.tiedMemberIds.map(g.memberName).join(' and ')} are level on votes. '
            'Talk it through with the group, then decide.',
      ),
      const SizedBox(height: 12),
      FilledButton.icon(
        key: const Key('settle-tie'),
        onPressed: _busy ? null : () => _settleTie(g),
        icon: const Icon(Icons.gavel_rounded),
        label: const Text('Settle the tie'),
      ),
    ];
  }
}

class _MethodTile extends StatelessWidget {
  const _MethodTile({required this.method, required this.selected, required this.onTap});

  final RoundMethod method;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    IconData icon = Icons.how_to_vote_rounded;
    if (method == RoundMethod.manual) icon = Icons.handshake_rounded;
    if (method == RoundMethod.random) icon = Icons.casino_rounded;
    return AppCard(
      onTap: onTap,
      color: selected ? AppColors.teal.withAlpha(30) : null,
      padding: const EdgeInsets.all(12),
      child: Row(
        children: <Widget>[
          Icon(icon, color: selected ? AppColors.teal : scheme.onSurfaceVariant),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(methodLabel(method), style: const TextStyle(fontWeight: FontWeight.w800)),
                Text(methodDescription(method),
                    style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12)),
              ],
            ),
          ),
          Icon(
            selected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
            color: selected ? AppColors.teal : scheme.outline,
          ),
        ],
      ),
    );
  }
}

class _EligibilityBox extends StatelessWidget {
  const _EligibilityBox({required this.group, required this.eligibility});

  final ChitGroup group;
  final Eligibility eligibility;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final blocked = eligibility.blockedMemberIds.map(group.memberName).toList()..sort();
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withAlpha(110),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Can win this month: ${eligibility.chits.map((c) => 'Chit ${c.number}').join(', ')}',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          if (blocked.isNotEmpty && !eligibility.relaxed)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '${blocked.join(', ')} received last month, so chits they own are left out.',
                style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
              ),
            ),
          if (eligibility.relaxed)
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text(
                'Every remaining chit involves someone paid last month, so the '
                '"not two months in a row" rule is eased: only chits with the least '
                'overlap can win.',
                style: TextStyle(color: AppColors.warning, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.group, required this.round});

  final ChitGroup group;
  final Round round;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final chit = round.winnerChitId == null ? null : group.chitById(round.winnerChitId!);
    return AppCard(
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.gold.withAlpha(40),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text('${round.number}', style: const TextStyle(fontWeight: FontWeight.w900)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(chit == null ? 'Decided' : group.chitLabel(chit),
                    style: const TextStyle(fontWeight: FontWeight.w800)),
                Text(
                  '${formatDate(round.announcementDate)}  ·  ${ChitActions.methodText(round)}',
                  style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
                ),
                if (round.resolution != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(round.resolution!, style: const TextStyle(fontSize: 13, height: 1.3)),
                  ),
              ],
            ),
          ),
          if (round.relaxed)
            const Padding(
              padding: EdgeInsets.only(left: 8),
              child: Pill(label: 'Rule eased', color: AppColors.warning),
            ),
        ],
      ),
    );
  }
}
