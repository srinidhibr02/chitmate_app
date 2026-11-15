library;

import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../domain/actions.dart';
import '../../domain/models.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../widgets/animated_bits.dart';
import '../widgets/common.dart';
import 'group_helpers.dart';

/// The group's message panel: announcements from the admin plus an automatic
/// log of every change (who, when, what).
class UpdatesTab extends StatefulWidget {
  const UpdatesTab({super.key, required this.groupId});

  final String groupId;

  @override
  State<UpdatesTab> createState() => _UpdatesTabState();
}

class _UpdatesTabState extends State<UpdatesTab> {
  final TextEditingController _text = TextEditingController();
  bool _onlyMessages = false;
  bool _sending = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _post(ChitGroup g) async {
    if (_sending) return;
    final message = _text.text;
    setState(() => _sending = true);
    final ok = await runAction(
      context,
      g.id,
      (group, a, actor) => a.postAnnouncement(group, message, actor: actor),
    );
    if (!mounted) return;
    setState(() => _sending = false);
    if (ok) _text.clear();
  }

  String _when(DateTime at) {
    final h = at.hour % 12 == 0 ? 12 : at.hour % 12;
    final m = at.minute.toString().padLeft(2, '0');
    return '${formatDate(at)}, $h:$m ${at.hour >= 12 ? 'pm' : 'am'}';
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final g = state.groupById(widget.groupId);
    if (g == null) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    final entries = g.feed
        .where((e) => !_onlyMessages || e.kind == FeedKind.announcement)
        .toList()
        .reversed
        .toList();
    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
          child: Row(
            children: <Widget>[
              ChoiceChip(
                label: const Text('Everything'),
                selected: !_onlyMessages,
                onSelected: (_) => setState(() => _onlyMessages = false),
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text('Announcements'),
                selected: _onlyMessages,
                onSelected: (_) => setState(() => _onlyMessages = true),
              ),
            ],
          ),
        ),
        Expanded(
          child: entries.isEmpty
              ? const EmptyState(
                  title: 'Nothing here yet',
                  message: 'Announcements and changes will appear here.',
                  icon: Icons.forum_outlined,
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  itemCount: entries.length,
                  itemBuilder: (context, i) {
                    final e = entries[i];
                    final isMessage = e.kind == FeedKind.announcement;
                    return FadeSlide(
                      index: i < 8 ? i : 0,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: AppCard(
                          onTap: () => copyText(context, e.text, what: 'Message copied'),
                          color: isMessage ? AppColors.teal.withAlpha(24) : null,
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Row(
                                children: <Widget>[
                                  Icon(
                                    isMessage
                                        ? Icons.campaign_rounded
                                        : (e.kind == FeedKind.system
                                            ? Icons.auto_awesome_rounded
                                            : Icons.edit_note_rounded),
                                    size: 16,
                                    color: isMessage ? AppColors.teal : scheme.onSurfaceVariant,
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      '${e.author}  ·  ${_when(e.at)}',
                                      style: TextStyle(
                                          fontSize: 12, color: scheme.onSurfaceVariant),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(e.text, style: const TextStyle(height: 1.35)),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                Expanded(
                  child: TextField(
                    key: const Key('announcement-field'),
                    controller: _text,
                    minLines: 1,
                    maxLines: 4,
                    maxLength: ChitActions.maxAnnouncementLength,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: appInput(context, label: 'Message to the group')
                        .copyWith(counterText: ''),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  key: const Key('send-announcement'),
                  tooltip: 'Post',
                  onPressed: _sending ? null : () => _post(g),
                  icon: const Icon(Icons.send_rounded),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
