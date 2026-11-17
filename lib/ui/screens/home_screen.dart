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
import 'create_group_screen.dart';
import 'group_screen.dart';
import 'rules_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  void _create(BuildContext context) {
    Navigator.of(context).push(softRoute<void>(const CreateGroupScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final groups = state.groups;
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      floatingActionButton: groups.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _create(context),
              icon: const Icon(Icons.add_rounded),
              label: const Text('New group'),
            ),
      body: CustomScrollView(
        slivers: <Widget>[
          SliverAppBar(
            pinned: true,
            titleSpacing: 16,
            title: Row(
              children: <Widget>[
                const AppLogo(size: 34),
                const SizedBox(width: 10),
                Text('ChitMate',
                    style: TextStyle(
                        fontWeight: FontWeight.w900, color: scheme.primary, fontSize: 22)),
              ],
            ),
            actions: <Widget>[
              IconButton(
                tooltip: 'How ChitMate works',
                icon: const Icon(Icons.help_outline_rounded),
                onPressed: () =>
                    Navigator.of(context).push(softRoute<void>(const RulesScreen())),
              ),
              IconButton(
                key: const Key('open-settings'),
                tooltip: 'Settings',
                icon: const Icon(Icons.settings_outlined),
                onPressed: () =>
                    Navigator.of(context).push(softRoute<void>(const SettingsScreen())),
              ),
              const SizedBox(width: 4),
            ],
          ),
          if (state.notice != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: NoticeBanner(
                  text: state.notice!,
                  icon: Icons.warning_amber_rounded,
                  color: AppColors.warning,
                  action: TextButton(onPressed: state.clearNotice, child: const Text('Dismiss')),
                ),
              ),
            ),
          if (state.saveProblem != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: NoticeBanner(
                  text: '${state.saveProblem!} Your latest changes may not be saved.',
                  icon: Icons.error_outline_rounded,
                  color: AppColors.danger,
                ),
              ),
            ),
          if (groups.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: EmptyState(
                showLogo: true,
                title: 'No chit groups yet',
                message: 'Create a group, add your members and their chits, and ChitMate '
                    'will run the monthly draw, votes and payments for you.',
                action: FilledButton.icon(
                  onPressed: () => _create(context),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Create your first group'),
                ),
              ),
            )
          else ...<Widget>[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: FadeSlide(child: _Summary(groups: groups, name: state.adminName, now: state.now)),
              ),
            ),
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(20, 12, 20, 4),
                child: SectionHeader('Your groups'),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 110),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, i) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: FadeSlide(
                      index: i + 1,
                      child: GroupCard(group: groups[i], now: state.now),
                    ),
                  ),
                  childCount: groups.length,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.groups, required this.name, required this.now});

  final List<ChitGroup> groups;
  final String name;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    ChitGroup? nextGroup;
    DateTime? nextDate;
    for (final g in groups) {
      final d = g.nextAnnouncement;
      if (d == null) continue;
      if (nextDate == null || d.isBefore(nextDate)) {
        nextDate = d;
        nextGroup = g;
      }
    }
    final active = groups.where((g) => g.started && !g.completed).length;
    return HeroCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Hello, $name', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(
            groups.length == 1 ? '1 group' : '${groups.length} groups',
            style: TextStyle(color: Colors.white.withAlpha(210)),
          ),
          const SizedBox(height: 18),
          Row(
            children: <Widget>[
              Expanded(child: _Stat(label: 'Active now', value: '$active')),
              Container(width: 1, height: 40, color: Colors.white.withAlpha(60)),
              Expanded(
                child: _Stat(
                  label: nextGroup == null ? 'Next announcement' : 'Next: ${nextGroup.name}',
                  value: nextDate == null ? 'Not set' : '${formatDayMonth(nextDate)} · ${countdownText(nextDate, now)}',
                  small: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, this.small = false});

  final String label;
  final String value;
  final bool small;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: Colors.white.withAlpha(190), fontSize: 12)),
          const SizedBox(height: 4),
          Text(value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: small ? 15 : 24, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

/// A group in the home list.
class GroupCard extends StatelessWidget {
  const GroupCard({super.key, required this.group, required this.now});

  final ChitGroup group;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final g = group;
    final double progress;
    final String ringText;
    if (g.started) {
      progress = g.rounds.isEmpty ? 0 : g.completedRounds / g.rounds.length;
      ringText = '${g.completedRounds}/${g.rounds.length}';
    } else {
      progress = Rules.setupProgress(g);
      ringText = '${(progress * 100).round()}%';
    }
    final next = g.nextAnnouncement;
    final Color statusColor = g.completed
        ? AppColors.success
        : (g.started ? scheme.primary : AppColors.warning);
    return AppCard(
      onTap: () => Navigator.of(context).push(softRoute<void>(GroupScreen(groupId: g.id))),
      child: Row(
        children: <Widget>[
          ProgressRing(
            progress: progress,
            size: 66,
            strokeWidth: 7,
            color: statusColor,
            trackColor: statusColor.withAlpha(34),
            child: Text(ringText,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(g.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(g.summaryLine,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: <Widget>[
                    Pill(label: groupStatusLabel(g), color: statusColor),
                    if (next != null && !g.completed)
                      Pill(
                        label: '${formatDayMonth(next)} · ${countdownText(next, now)}',
                        color: scheme.onSurfaceVariant,
                        icon: Icons.event_rounded,
                      ),
                  ],
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: scheme.onSurfaceVariant),
        ],
      ),
    );
  }
}
