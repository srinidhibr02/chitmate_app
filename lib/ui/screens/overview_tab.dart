library;

import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../domain/labels.dart';
import '../../domain/models.dart';
import '../../domain/rules.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../widgets/animated_bits.dart';
import '../widgets/common.dart';
import 'group_dialogs.dart';
import 'group_helpers.dart';

class OverviewTab extends StatelessWidget {
  const OverviewTab({super.key, required this.groupId, required this.onSelectTab});

  final String groupId;
  final void Function(int tab) onSelectTab;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final g = state.groupById(groupId);
    if (g == null) return const SizedBox.shrink();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: g.started
          ? _startedContent(context, g, state.now)
          : _setupContent(context, g),
    );
  }

  // ------------------------------------------------------------- setup --

  List<Widget> _setupContent(BuildContext context, ChitGroup g) {
    final scheme = Theme.of(context).colorScheme;
    final issues = Rules.readiness(g);
    final blocking = issues.where((i) => i.blocking).toList();
    final warnings = issues.where((i) => !i.blocking).toList();
    final value = g.chitValue;
    final chitsValid = g.chits.length >= 2 &&
        value != null &&
        g.chits.every((c) => Rules.sharesError(g, c.shares) == null);
    final planned = g.plannedMembers;
    final memberText = planned == null
        ? plural(g.members.length, 'member')
        : '${g.members.length} of $planned members';
    return <Widget>[
      FadeSlide(
        child: HeroCard(
          child: Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text('Set up your group',
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 6),
                    Text(
                      'Add members and their chits, pick the first date, then start the cycle.',
                      style: TextStyle(color: Colors.white.withAlpha(215), height: 1.35),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              ProgressRing(
                progress: Rules.setupProgress(g),
                size: 78,
                strokeWidth: 8,
                color: Colors.white,
                trackColor: Colors.white.withAlpha(60),
                child: Text('${(Rules.setupProgress(g) * 100).round()}%',
                    style: const TextStyle(fontWeight: FontWeight.w800)),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 16),
      FadeSlide(
        index: 1,
        child: AppCard(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
          child: Column(
            children: <Widget>[
              _StepRow(
                done: value != null && value > 0,
                title: 'Chit value',
                subtitle: value == null
                    ? 'How much does one chit cost each month?'
                    : '${rupees(value)} per chit each month',
                action: value == null ? 'Set' : 'Change',
                onAction: () => editChitValue(context, g),
              ),
              _StepRow(
                done: g.members.length >= 2,
                title: 'Members',
                subtitle: memberText,
                action: 'Add',
                onAction: () => onSelectTab(1),
              ),
              _StepRow(
                done: chitsValid,
                title: 'Chits and shares',
                subtitle: g.chits.isEmpty
                    ? 'Add at least 2 chits'
                    : '${plural(g.chits.length, 'chit')} · pool ${rupees(g.poolAmount)}',
                action: 'Manage',
                onAction: () => onSelectTab(1),
              ),
              _StepRow(
                done: g.firstAnnouncementDate != null,
                title: 'First announcement date',
                subtitle: g.firstAnnouncementDate == null
                    ? 'When is the first chit announced?'
                    : formatDateLong(g.firstAnnouncementDate!),
                action: g.firstAnnouncementDate == null ? 'Pick' : 'Change',
                onAction: () => pickFirstAnnouncement(context, g),
                last: true,
              ),
            ],
          ),
        ),
      ),
      if (blocking.isNotEmpty) ...<Widget>[
        const SizedBox(height: 16),
        FadeSlide(
          index: 2,
          child: NoticeBanner(
            icon: Icons.checklist_rounded,
            color: AppColors.warning,
            text: 'Still to do:\n${blocking.map((i) => '• ${i.message}').join('\n')}',
          ),
        ),
      ],
      for (final w in warnings) ...<Widget>[
        const SizedBox(height: 12),
        FadeSlide(
          index: 3,
          child: NoticeBanner(
            icon: Icons.lightbulb_outline_rounded,
            color: scheme.primary,
            text: w.message,
          ),
        ),
      ],
      const SizedBox(height: 20),
      FadeSlide(
        index: 4,
        child: FilledButton.icon(
          onPressed: blocking.isEmpty ? () => _start(context, g) : null,
          icon: const Icon(Icons.rocket_launch_rounded),
          label: const Text('Start the cycle'),
        ),
      ),
    ];
  }

  Future<void> _start(BuildContext context, ChitGroup g) async {
    final ok = await confirmDialog(
      context,
      title: 'Start the cycle?',
      message: 'This locks the chit value and the number of chits '
          '(${g.chits.length} chits, ${rupees(g.chitValue ?? 0)} each, a pool of '
          '${rupees(g.poolAmount)} for ${plural(g.chits.length, 'month')}). '
          'Shares of chits that have not won can still be changed later, with everyone\'s agreement.',
      confirmLabel: 'Start',
    );
    if (!ok || !context.mounted) return;
    final done = await runAction(
      context,
      g.id,
      (group, a, actor) => a.startCycle(group, actor: actor),
      success: 'The cycle has started.',
    );
    if (done && context.mounted) onSelectTab(2);
  }

  // ----------------------------------------------------------- started --

  List<Widget> _startedContent(BuildContext context, ChitGroup g, DateTime now) {
    final scheme = Theme.of(context).colorScheme;
    final cur = g.currentRound;
    final total = g.rounds.length;
    final remaining = Rules.unwonChits(g).length;
    final warnings = Rules.concentrationWarnings(g);
    return <Widget>[
      FadeSlide(
        child: HeroCard(
          child: Column(
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text('Monthly pool',
                            style: TextStyle(color: Colors.white.withAlpha(200))),
                        const SizedBox(height: 4),
                        AnimatedRupees(
                          value: g.poolAmount,
                          style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${rupees(g.chitValue ?? 0)} × ${plural(g.chitCount, 'chit')}',
                          style: TextStyle(color: Colors.white.withAlpha(200)),
                        ),
                      ],
                    ),
                  ),
                  ProgressRing(
                    progress: total == 0 ? 0 : g.completedRounds / total,
                    size: 84,
                    color: Colors.white,
                    trackColor: Colors.white.withAlpha(60),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text('${g.completedRounds}/$total',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                        Text('months',
                            style: TextStyle(fontSize: 10, color: Colors.white.withAlpha(200))),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Divider(color: Colors.white.withAlpha(50), height: 1),
              const SizedBox(height: 14),
              Row(
                children: <Widget>[
                  Expanded(
                    child: _MiniStat(
                      label: 'Next announcement',
                      value: cur == null ? 'All done' : formatDayMonth(cur.announcementDate),
                      sub: cur == null ? null : countdownText(cur.announcementDate, now),
                    ),
                  ),
                  Expanded(child: _MiniStat(label: 'Members', value: '${g.members.length}')),
                  Expanded(child: _MiniStat(label: 'Chits left', value: '$remaining')),
                ],
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 16),
      if (cur != null)
        FadeSlide(
          index: 1,
          child: AppCard(
            onTap: () => onSelectTab(2),
            child: Row(
              children: <Widget>[
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: scheme.tertiary.withAlpha(60),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(Icons.how_to_vote_rounded, color: AppColors.goldDark),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text('Month ${cur.number}: ${roundStatusLabel(cur.status)}',
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                      const SizedBox(height: 2),
                      Text(
                        _nextStepText(cur),
                        style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: scheme.onSurfaceVariant),
              ],
            ),
          ),
        )
      else
        FadeSlide(
          index: 1,
          child: NoticeBanner(
            icon: Icons.celebration_rounded,
            color: AppColors.success,
            text: 'Every chit has had its turn. The scheme is complete. Please settle any '
                'pending payments in the Payments tab.',
          ),
        ),
      for (final w in warnings) ...<Widget>[
        const SizedBox(height: 12),
        FadeSlide(
          index: 2,
          child: NoticeBanner(
            icon: Icons.balance_rounded,
            color: AppColors.warning,
            text: '${g.memberName(w.memberId)} holds ${w.votes} of ${w.total} votes '
                '(${(w.share * 100).round()}%), so votes can be steered by one person.',
          ),
        ),
      ],
      const SizedBox(height: 8),
      const SectionHeader('All months'),
      for (var i = 0; i < g.rounds.length; i++)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: FadeSlide(
            index: i + 2,
            child: _RoundTile(group: g, round: g.rounds[i], onTap: () => onSelectTab(2)),
          ),
        ),
    ];
  }

  String _nextStepText(Round r) {
    if (r.status == RoundStatus.pending) return 'Choose how this month\'s chit is picked.';
    if (r.status == RoundStatus.awaitingTieBreak) return 'The vote is tied. The admin decides.';
    if (r.status == RoundStatus.completed) return 'Decided.';
    final m = r.method;
    if (m == RoundMethod.vote) return 'Voting is open. Record votes, then count them.';
    if (m == RoundMethod.manual) return 'Record the chit the group agreed on.';
    if (m == RoundMethod.random) return 'Ready for the random draw.';
    return 'In progress.';
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({
    required this.done,
    required this.title,
    required this.subtitle,
    required this.action,
    required this.onAction,
    this.last = false,
  });

  final bool done;
  final String title;
  final String subtitle;
  final String action;
  final VoidCallback onAction;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = done ? AppColors.success : scheme.onSurfaceVariant;
    return Column(
      children: <Widget>[
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 8),
          leading: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
            child: Icon(
              done ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
              key: ValueKey<bool>(done),
              color: color,
              size: 28,
            ),
          ),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Text(subtitle),
          trailing: TextButton(onPressed: onAction, child: Text(action)),
        ),
        if (!last) Divider(height: 1, indent: 56, color: scheme.outlineVariant.withAlpha(90)),
      ],
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.value, this.sub});

  final String label;
  final String value;
  final String? sub;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: Colors.white.withAlpha(190), fontSize: 11)),
        const SizedBox(height: 3),
        Text(value, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
        if (sub != null)
          Text(sub!, style: TextStyle(color: Colors.white.withAlpha(200), fontSize: 11)),
      ],
    );
  }
}

class _RoundTile extends StatelessWidget {
  const _RoundTile({required this.group, required this.round, required this.onTap});

  final ChitGroup group;
  final Round round;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final r = round;
    final cur = group.currentRound;
    final isCurrent = cur != null && cur.index == r.index;
    final chitId = r.winnerChitId;
    final chit = chitId == null ? null : group.chitById(chitId);
    final Color accent = r.isCompleted
        ? AppColors.success
        : (isCurrent ? scheme.primary : scheme.onSurfaceVariant);
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: <Widget>[
          Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: accent.withAlpha(30), shape: BoxShape.circle),
            child: r.isCompleted
                ? Icon(Icons.emoji_events_rounded, color: accent, size: 22)
                : Text('${r.number}',
                    style: TextStyle(color: accent, fontWeight: FontWeight.w900, fontSize: 16)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  chit == null ? 'Month ${r.number}' : 'Month ${r.number} · ${group.chitLabel(chit)}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 2),
                Text(
                  chit == null
                      ? formatDateLong(r.announcementDate)
                      : '${formatDate(r.announcementDate)} · wins ${rupees(group.poolAmount)}',
                  style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
                ),
              ],
            ),
          ),
          if (isCurrent) const Pill(label: 'Now', color: AppColors.teal),
        ],
      ),
    );
  }
}
