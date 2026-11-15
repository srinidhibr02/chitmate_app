library;

import 'package:flutter/material.dart';

import '../../domain/labels.dart';
import '../../domain/notices.dart';
import '../../state/app_state.dart';
import '../widgets/common.dart';
import 'chits_tab.dart';
import 'group_helpers.dart';
import 'group_settings_screen.dart';
import 'overview_tab.dart';
import 'payments_tab.dart';
import 'round_tab.dart';
import 'updates_tab.dart';

/// One chit group, with its five tabs.
class GroupScreen extends StatefulWidget {
  const GroupScreen({super.key, required this.groupId, this.initialTab = 0});

  final String groupId;
  final int initialTab;

  @override
  State<GroupScreen> createState() => _GroupScreenState();
}

class _GroupScreenState extends State<GroupScreen> {
  late int _tab = widget.initialTab;

  void _select(int i) => setState(() => _tab = i);

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final g = state.groupById(widget.groupId);
    if (g == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const EmptyState(
          title: 'This group is gone',
          message: 'It may have been deleted.',
          icon: Icons.search_off_rounded,
        ),
      );
    }
    final scheme = Theme.of(context).colorScheme;
    final tabs = <Widget>[
      OverviewTab(groupId: g.id, onSelectTab: _select),
      ChitsTab(groupId: g.id),
      RoundTab(groupId: g.id),
      PaymentsTab(groupId: g.id),
      UpdatesTab(groupId: g.id),
    ];
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(g.name, maxLines: 1, overflow: TextOverflow.ellipsis),
            Text(
              groupStatusLabel(g),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        actions: <Widget>[
          IconButton(
            tooltip: 'Copy group info for WhatsApp',
            icon: const Icon(Icons.ios_share_rounded),
            onPressed: () => copyText(context, Notices.groupInfo(g), what: 'Group info copied'),
          ),
          IconButton(
            tooltip: 'Group settings',
            icon: const Icon(Icons.tune_rounded),
            onPressed: () => Navigator.of(context)
                .push(softRoute<void>(GroupSettingsScreen(groupId: g.id))),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 260),
        switchInCurve: Curves.easeOutCubic,
        child: KeyedSubtree(key: ValueKey<int>(_tab), child: tabs[_tab]),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: _select,
        destinations: const <NavigationDestination>[
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard_rounded),
            label: 'Overview',
          ),
          NavigationDestination(
            icon: Icon(Icons.pie_chart_outline_rounded),
            selectedIcon: Icon(Icons.pie_chart_rounded),
            label: 'Chits',
          ),
          NavigationDestination(
            icon: Icon(Icons.how_to_vote_outlined),
            selectedIcon: Icon(Icons.how_to_vote_rounded),
            label: 'Round',
          ),
          NavigationDestination(
            icon: Icon(Icons.account_balance_wallet_outlined),
            selectedIcon: Icon(Icons.account_balance_wallet_rounded),
            label: 'Payments',
          ),
          NavigationDestination(
            icon: Icon(Icons.forum_outlined),
            selectedIcon: Icon(Icons.forum_rounded),
            label: 'Updates',
          ),
        ],
      ),
    );
  }
}
