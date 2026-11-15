library;

import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../domain/models.dart';
import '../../domain/rules.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../sheets/chit_editor_screen.dart';
import '../sheets/member_sheet.dart';
import '../widgets/animated_bits.dart';
import '../widgets/common.dart';
import 'group_dialogs.dart';

/// "Group info": every member and every chit, with co-owners shown openly.
class ChitsTab extends StatelessWidget {
  const ChitsTab({super.key, required this.groupId});

  final String groupId;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final g = state.groupById(groupId);
    if (g == null) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    final won = Rules.wonChitIds(g);
    final warnings = Rules.concentrationWarnings(g);
    final canAddChit = !g.started && g.chitValue != null;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: <Widget>[
        FadeSlide(
          child: SectionHeader(
            'Members',
            subtitle: g.plannedMembers == null
                ? plural(g.members.length, 'member')
                : '${g.members.length} of ${g.plannedMembers} planned',
            trailing: FilledButton.tonalIcon(
              key: const Key('add-member'),
              onPressed: () => showMemberSheet(context, g.id),
              icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
              label: const Text('Add'),
            ),
          ),
        ),
        if (g.members.isEmpty)
          const EmptyState(
            title: 'No members yet',
            message: 'Add the people in your chit group. You can always add more later.',
            icon: Icons.groups_rounded,
          ),
        for (var i = 0; i < g.members.length; i++)
          FadeSlide(
            index: i,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _MemberTile(group: g, member: g.members[i]),
            ),
          ),
        for (final w in warnings) ...<Widget>[
          const SizedBox(height: 4),
          NoticeBanner(
            icon: Icons.warning_amber_rounded,
            color: AppColors.warning,
            text: '${g.memberName(w.memberId)} holds ${w.votes} of ${w.total} votes '
                '(${(w.share * 100).round()}%), so they can steer most votes. '
                'Consider random or agreed picks.',
          ),
        ],
        const SizedBox(height: 12),
        SectionHeader(
          'Chits',
          subtitle: g.chitValue == null
              ? 'Set the chit value to add chits'
              : '${plural(g.chits.length, 'chit')} of ${rupees(g.chitValue!)}',
          trailing: FilledButton.tonalIcon(
            key: const Key('add-chit'),
            onPressed: canAddChit
                ? () => Navigator.of(context)
                    .push(softRoute<void>(ChitEditorScreen(groupId: g.id)))
                : null,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('New chit'),
          ),
        ),
        if (g.chitValue == null)
          NoticeBanner(
            text: 'Every chit is worth the same amount each month. Set it first.',
            action: FilledButton.tonal(
              onPressed: () => editChitValue(context, g),
              child: const Text('Set chit value'),
            ),
          ),
        if (g.started)
          const NoticeBanner(
            icon: Icons.lock_outline_rounded,
            text: 'The cycle has started: the number of chits is locked. '
                'Shares of chits that have not won can still be changed if the '
                'co-owners agree.',
          ),
        if (g.chits.isEmpty && g.chitValue != null)
          const EmptyState(
            title: 'No chits yet',
            message: 'A chit can belong to one person or be shared between several.',
            icon: Icons.pie_chart_outline_rounded,
          ),
        for (var i = 0; i < g.chits.length; i++)
          FadeSlide(
            index: i,
            child: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: _ChitTile(
                group: g,
                chit: g.chits[i],
                won: won.contains(g.chits[i].id),
                scheme: scheme,
              ),
            ),
          ),
      ],
    );
  }
}

class _MemberTile extends StatelessWidget {
  const _MemberTile({required this.group, required this.member});

  final ChitGroup group;
  final Member member;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final due = Rules.monthlyDue(group, member.id);
    final power = Rules.votingPower(group, member.id);
    final chitNumbers =
        group.chits.where((c) => c.ownedBy(member.id)).map((c) => '${c.number}').toList();
    return AppCard(
      onTap: () => showMemberSheet(context, group.id, member: member),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: <Widget>[
          MemberAvatar(name: member.name, size: 44),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(member.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                const SizedBox(height: 2),
                Text(
                  chitNumbers.isEmpty
                      ? 'No chit yet'
                      : 'Chit ${chitNumbers.join(', ')}  ·  ${rupees(due)} a month',
                  style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
                ),
              ],
            ),
          ),
          if (group.chits.isNotEmpty)
            Pill(
              label: plural(power, 'vote'),
              color: power == 0 ? scheme.outline : AppColors.teal,
              icon: Icons.how_to_vote_rounded,
            ),
        ],
      ),
    );
  }
}

class _ChitTile extends StatelessWidget {
  const _ChitTile({
    required this.group,
    required this.chit,
    required this.won,
    required this.scheme,
  });

  final ChitGroup group;
  final Chit chit;
  final bool won;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    final payouts = Rules.payoutFor(group, chit);
    final owners = chit.shares.entries.toList()
      ..sort((a, b) => group.memberName(a.key).compareTo(group.memberName(b.key)));
    Round? wonRound;
    for (final r in group.rounds) {
      if (r.winnerChitId == chit.id) wonRound = r;
    }
    return AppCard(
      onTap: won
          ? null
          : () => Navigator.of(context).push(
                softRoute<void>(ChitEditorScreen(groupId: group.id, chitId: chit.id)),
              ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.teal.withAlpha(30),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text('${chit.number}',
                    style: const TextStyle(
                        fontWeight: FontWeight.w900, color: AppColors.teal, fontSize: 16)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  chit.isFull ? 'Chit ${chit.number}' : 'Chit ${chit.number} · shared',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                ),
              ),
              if (wonRound != null)
                Pill(
                  label: 'Won month ${wonRound.number}',
                  color: AppColors.gold,
                  icon: Icons.emoji_events_rounded,
                )
              else if (group.started)
                const Pill(label: 'Still in', color: AppColors.teal),
            ],
          ),
          const SizedBox(height: 10),
          for (final e in owners)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: <Widget>[
                  MemberAvatar(name: group.memberName(e.key), size: 26),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(group.memberName(e.key),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                  Text(
                    chit.isFull
                        ? rupees(e.value)
                        : '${rupees(e.value)}  →  gets ${rupees(payouts[e.key] ?? 0)}',
                    style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
                  ),
                ],
              ),
            ),
          if (chit.isFull)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Receives ${rupees(payouts[chit.ownerIds.first] ?? 0)} if it wins',
                style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
              ),
            ),
        ],
      ),
    );
  }
}
