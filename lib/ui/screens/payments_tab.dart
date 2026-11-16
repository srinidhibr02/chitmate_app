library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/format.dart';
import '../../domain/labels.dart';
import '../../domain/models.dart';
import '../../domain/notices.dart';
import '../../domain/rules.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../widgets/animated_bits.dart';
import '../widgets/common.dart';
import 'group_helpers.dart';

/// Who has paid this month and who has been handed the payout.
/// Payments are only tracked here; no money moves through the app.
class PaymentsTab extends StatefulWidget {
  const PaymentsTab({super.key, required this.groupId});

  final String groupId;

  @override
  State<PaymentsTab> createState() => _PaymentsTabState();
}

class _PaymentsTabState extends State<PaymentsTab> {
  int? _selected;

  Color _statusColor(PaymentStatus s) {
    switch (s) {
      case PaymentStatus.paid:
        return AppColors.success;
      case PaymentStatus.partial:
        return AppColors.warning;
      case PaymentStatus.pending:
        return AppColors.teal;
      case PaymentStatus.overdue:
        return AppColors.danger;
    }
  }

  Future<void> _editPayment(ChitGroup g, Round r, Member m) async {
    final due = Rules.monthlyDue(g, m.id);
    final paid = Rules.paidBy(r, m.id);
    final value = await showAppSheet<int>(context, (ctx) {
      return _PaymentSheet(name: m.name, due: due, paid: paid);
    });
    if (value == null || !mounted) return;
    await runAction(
      context,
      g.id,
      (group, a, actor) => a.recordPayment(group, r.index, memberId: m.id, amount: value, actor: actor),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final g = state.groupById(widget.groupId);
    if (g == null) return const SizedBox.shrink();
    if (!g.started || g.rounds.isEmpty) {
      return const EmptyState(
        title: 'No payments to track yet',
        message: 'Once the cycle starts, you can mark who has paid each month here.',
        icon: Icons.account_balance_wallet_outlined,
      );
    }
    final scheme = Theme.of(context).colorScheme;
    final now = state.now;
    final defaultIndex = (g.currentRound ?? g.rounds.last).index;
    var index = _selected ?? defaultIndex;
    if (index < 0 || index >= g.rounds.length) index = defaultIndex;
    final r = g.rounds[index];
    final pool = g.poolAmount;
    final collected = Rules.collected(r);
    final payers = g.members.where((m) => Rules.monthlyDue(g, m.id) > 0).toList();
    final payouts = Rules.roundPayouts(g, r);
    final recipients = payouts.entries.toList()
      ..sort((a, b) => g.memberName(a.key).compareTo(g.memberName(b.key)));

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: <Widget>[
        SizedBox(
          height: 44,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: g.rounds.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              final round = g.rounds[i];
              return ChoiceChip(
                label: Text('Month ${round.number}'),
                avatar: round.isCompleted ? const Icon(Icons.check_rounded, size: 16) : null,
                selected: i == index,
                onSelected: (_) => setState(() => _selected = i),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        FadeSlide(
          child: HeroCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('Month ${r.number} · due by ${formatDate(r.announcementDate)}',
                    style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                AnimatedRupees(
                  value: collected,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 34, fontWeight: FontWeight.w900),
                ),
                Text('collected of ${rupees(pool)}',
                    style: const TextStyle(color: Colors.white70)),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: pool == 0 ? 0 : (collected / pool).clamp(0.0, 1.0).toDouble(),
                    minHeight: 8,
                    color: AppColors.gold,
                    backgroundColor: Colors.white24,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        SectionHeader(
          'Contributions',
          trailing: TextButton.icon(
            key: const Key('copy-reminder'),
            onPressed: () =>
                copyText(context, Notices.paymentReminder(g, r), what: 'Reminder copied'),
            icon: const Icon(Icons.copy_rounded, size: 18),
            label: const Text('Copy reminder'),
          ),
        ),
        for (var i = 0; i < payers.length; i++)
          FadeSlide(
            index: i,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Builder(builder: (context) {
                final m = payers[i];
                final due = Rules.monthlyDue(g, m.id);
                final paid = Rules.paidBy(r, m.id);
                final status = Rules.paymentStatus(g, r, m.id, now);
                final color = _statusColor(status);
                return AppCard(
                  onTap: () => _editPayment(g, r, m),
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: <Widget>[
                      MemberAvatar(name: m.name, size: 40),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(m.left ? '${m.name} (left)' : m.name,
                                style: const TextStyle(fontWeight: FontWeight.w800)),
                            Text('${rupees(paid)} of ${rupees(due)}',
                                style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13)),
                          ],
                        ),
                      ),
                      Pill(label: paymentStatusLabel(status), color: color),
                    ],
                  ),
                );
              }),
            ),
          ),
        if (r.isCompleted && recipients.isNotEmpty) ...<Widget>[
          const SizedBox(height: 8),
          const SectionHeader('Payout', subtitle: 'Mark it once handed over'),
          for (final e in recipients)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: AppCard(
                padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
                child: Row(
                  children: <Widget>[
                    MemberAvatar(name: g.memberName(e.key), size: 40),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(g.memberName(e.key),
                              style: const TextStyle(fontWeight: FontWeight.w800)),
                          Text(rupees(e.value),
                              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13)),
                        ],
                      ),
                    ),
                    Text(r.payoutsDone.contains(e.key) ? 'Given' : 'Not given',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: r.payoutsDone.contains(e.key)
                                ? AppColors.success
                                : scheme.onSurfaceVariant)),
                    Switch(
                      value: r.payoutsDone.contains(e.key),
                      onChanged: (v) => runAction(
                        context,
                        g.id,
                        (group, a, actor) => a.setPayoutDone(group, r.index,
                            memberId: e.key, done: v, actor: actor),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
        if (!r.isCompleted)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: NoticeBanner(
              text: 'ChitMate only keeps track of payments. Collect the money the way '
                  'your group already does.',
            ),
          ),
      ],
    );
  }
}

class _PaymentSheet extends StatefulWidget {
  const _PaymentSheet({
    required this.name,
    required this.due,
    required this.paid,
  });

  final String name;
  final int due;
  final int paid;

  @override
  State<_PaymentSheet> createState() => _PaymentSheetState();
}

class _PaymentSheetState extends State<_PaymentSheet> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.paid == 0 ? '' : '${widget.paid}');
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    final text = _controller.text.trim();
    final n = text.isEmpty ? 0 : int.tryParse(text);
    if (n == null || n < 0 || n > widget.due) {
      setState(() => _error = 'Enter an amount from ₹0 to ${rupees(widget.due)}');
      return;
    }
    Navigator.of(context).pop(n);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text('${widget.name}\'s payment',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text('Owes ${rupees(widget.due)} this month.'),
          const SizedBox(height: 14),
          TextField(
            key: const Key('payment-amount'),
            controller: _controller,
            keyboardType: TextInputType.number,
            inputFormatters: <TextInputFormatter>[FilteringTextInputFormatter.digitsOnly],
            decoration: appInput(context, label: 'Amount paid', prefixText: '₹ ')
                .copyWith(errorText: _error),
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _controller.text = '${widget.due}',
                  child: const Text('Paid in full'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _controller.text = '',
                  child: const Text('Clear'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FilledButton(
            key: const Key('save-payment'),
            onPressed: _save,
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
