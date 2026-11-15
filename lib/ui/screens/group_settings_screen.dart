library;

import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../domain/actions.dart';
import '../../domain/notices.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../widgets/common.dart';
import 'group_dialogs.dart';
import 'group_helpers.dart';
import 'rules_screen.dart';

/// Group name, chit value, dates, reminders and deleting the group.
class GroupSettingsScreen extends StatelessWidget {
  const GroupSettingsScreen({super.key, required this.groupId});

  final String groupId;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final g = state.groupById(groupId);
    if (g == null) {
      return Scaffold(appBar: AppBar(), body: const SizedBox.shrink());
    }
    final scheme = Theme.of(context).colorScheme;
    final cur = g.currentRound;

    Widget tile({
      required IconData icon,
      required String title,
      required String value,
      VoidCallback? onTap,
      bool locked = false,
      Key? key,
    }) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: AppCard(
          key: key,
          onTap: onTap,
          padding: const EdgeInsets.all(14),
          child: Row(
            children: <Widget>[
              Icon(icon, color: AppColors.teal),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
                    Text(value, style: TextStyle(color: scheme.onSurfaceVariant)),
                  ],
                ),
              ),
              Icon(locked ? Icons.lock_outline_rounded : Icons.chevron_right_rounded,
                  color: scheme.outline),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Group settings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: <Widget>[
          tile(
            key: const Key('setting-name'),
            icon: Icons.edit_rounded,
            title: 'Group name',
            value: g.name,
            onTap: () async {
              final name = await promptText(context, title: 'Group name', label: 'Name', initial: g.name);
              if (name == null || !context.mounted) return;
              await runAction(context, g.id, (group, a, actor) => a.renameGroup(group, name, actor: actor));
            },
          ),
          tile(
            key: const Key('setting-chit-value'),
            icon: Icons.currency_rupee_rounded,
            title: 'Chit value',
            value: g.chitValue == null ? 'Not set' : '${rupees(g.chitValue!)} a month',
            locked: g.started,
            onTap: g.started
                ? () => showSnack(context, 'The chit value is locked once the first month has started.')
                : () => editChitValue(context, g),
          ),
          tile(
            key: const Key('setting-planned'),
            icon: Icons.groups_rounded,
            title: 'Planned number of members',
            value: g.plannedMembers == null ? 'Not set' : '${g.plannedMembers}',
            onTap: () async {
              final n = await promptInt(
                context,
                title: 'Planned members',
                label: 'How many people will join?',
                initial: g.plannedMembers,
                min: 2,
                max: ChitActions.maxMembers,
              );
              if (n == null || !context.mounted) return;
              await runAction(context, g.id, (group, a, actor) => a.setPlannedMembers(group, n, actor: actor));
            },
          ),
          if (!g.started)
            tile(
              key: const Key('setting-first-date'),
              icon: Icons.event_rounded,
              title: 'First announcement date',
              value: g.firstAnnouncementDate == null
                  ? 'Not set'
                  : formatDateLong(g.firstAnnouncementDate!),
              onTap: () => pickFirstAnnouncement(context, g),
            )
          else if (cur != null)
            tile(
              key: const Key('setting-reschedule'),
              icon: Icons.event_repeat_rounded,
              title: 'Next announcement',
              value: '${formatDateLong(cur.announcementDate)} (tap to move)',
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: cur.announcementDate,
                  firstDate: DateTime(2000),
                  lastDate: DateTime(2100),
                  helpText: 'Move this and later announcements',
                );
                if (picked == null || !context.mounted) return;
                await runAction(
                  context,
                  g.id,
                  (group, a, actor) => a.reschedule(group, picked, actor: actor),
                );
              },
            ),
          const SizedBox(height: 4),
          AppCard(
            padding: const EdgeInsets.fromLTRB(14, 6, 8, 6),
            child: Row(
              children: <Widget>[
                const Icon(Icons.notifications_active_rounded, color: AppColors.teal),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text('Reminders', style: TextStyle(fontWeight: FontWeight.w800)),
                      Text('3 days before each announcement, at 9:00 am'),
                    ],
                  ),
                ),
                Switch(
                  key: const Key('setting-reminders'),
                  value: g.remindersEnabled,
                  onChanged: (v) async {
                    if (v) {
                      final allowed = await state.enableReminders();
                      if (!context.mounted) return;
                      if (!allowed) {
                        showSnack(context,
                            'Notifications are turned off for ChitMate in your phone settings.',
                            error: true);
                      }
                    }
                    if (!context.mounted) return;
                    await runAction(context, g.id, (group, a, actor) => a.setRemindersEnabled(group, v));
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          tile(
            icon: Icons.ios_share_rounded,
            title: 'Copy group info',
            value: 'Paste it into your WhatsApp group',
            onTap: () => copyText(context, Notices.groupInfo(g), what: 'Group info copied'),
          ),
          tile(
            icon: Icons.menu_book_rounded,
            title: 'How it works',
            value: 'The rules in plain words',
            onTap: () => Navigator.of(context).push(softRoute<void>(const RulesScreen())),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            key: const Key('delete-group'),
            style: OutlinedButton.styleFrom(
              foregroundColor: scheme.error,
              side: BorderSide(color: scheme.error.withAlpha(120)),
            ),
            onPressed: () async {
              final navigator = Navigator.of(context);
              final ok = await confirmDialog(
                context,
                title: 'Delete "${g.name}"?',
                message: 'Everything in this group is removed from this phone. '
                    'This cannot be undone.',
                confirmLabel: 'Delete',
                destructive: true,
              );
              if (!ok) return;
              await state.deleteGroup(g.id);
              navigator.popUntil((route) => route.isFirst);
            },
            icon: const Icon(Icons.delete_outline_rounded),
            label: const Text('Delete this group'),
          ),
        ],
      ),
    );
  }
}
